#!/usr/bin/env python3
"""
Vibe-coded with Z.ai.

Request and download support tickets (diagnostics) from an HPE MSL tape
library through its undocumented REST API (the one CVTL uses).

Endpoints reverse-engineered from cvtl.jar (AngusRestClientApi +
DriveDeserializer / ResultStatusDeserializer):
  base:   https://<host>:3031/v1           Basic auth, user "cvtl" + REST password
  GET     /drive                           -> {"data": {"DRIVE": [[col names...],
                                              [values...], ...]}} (row 0 = header;
                                              DRIVE_PHY_NUM = element address)
  GET     /stack/library-plr-ticket        -> library support ticket (.ltd, octet-stream)
  GET     /drive/drive-plr-ticket/{phy}    -> drive support ticket (.ltd, octet-stream)

There is no login endpoint: every request carries HTTP Basic auth. The TLS
certificate is always self-signed, so verification is off by default.

Ticket generation happens server-side while the GET is pending and can take
several minutes per ticket; library and drive tickets are fetched in parallel.

Requires python3-requests.

Usage:
  ./get-sticket.py --host 10.0.0.10
  (user defaults to cvtl; password is read from $MSL_PASSWORD or prompted)
"""
import argparse
import concurrent.futures
import getpass
import json
import os
import re
import requests
import sys
import time
import urllib3


class MSLRestClient:
    def __init__(self, host, user, password, verify=False, port=3031):
        self.base = f"https://{host}:{port}/v1"
        self.s = requests.Session()
        self.s.verify = verify
        self.s.auth = (user, password)
        # CVTL sends a JSON media type on every request, including GETs.
        self.s.headers.update({"Accept": "application/json",
                               "Content-Type": "application/json"})
        if not verify:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    def _get(self, path, timeout, retries=3):
        for attempt in range(retries):
            try:
                return self.s.get(self.base + path, timeout=timeout)
            except requests.RequestException as e:
                if attempt == retries - 1:
                    raise
                print(f"[debug] {path} attempt {attempt + 1} failed: {e}; retrying...",
                      file=sys.stderr)
                time.sleep(2 * (attempt + 1))

    @staticmethod
    def _status_from_json(body):
        """Extract ERRORCODE/ERRORMESSAGEDB from the RES_STATUS table,
        e.g. {"data": {"RES_STATUS": [["ERRORCODE","ERC..."],[...]]}}."""
        out = {}
        try:
            rows = body["data"]["RES_STATUS"]
            for row in rows:
                if len(row) >= 2:
                    out[row[0]] = row[1]
        except (KeyError, TypeError, ValueError):
            pass
        return out

    def _check_auth(self, r):
        if r.status_code == 401:
            raise RuntimeError("Unauthorized. Check library REST authentication "
                               "(REST password set on the library control panel).")

    # ---- inventory ------------------------------------------------------
    def get_drives(self, timeout=120):
        """Return the drive inventory as a list of dicts keyed by the
        library's column names (DRIVE_PHY_NUM, DRIVE_MANUF_SERIAL_NO, ...)."""
        r = self._get("/drive", timeout)
        self._check_auth(r)
        if not r.ok:
            raise RuntimeError(f"GET /drive -> {r.status_code}: {r.text[:500]}")
        try:
            table = r.json()["data"]["DRIVE"]
            header = [c for c in table[0]]
            drives = []
            for row in table[1:]:
                d = {header[i]: row[i] for i in range(min(len(header), len(row)))}
                drives.append(d)
            return drives
        except (KeyError, TypeError, ValueError, IndexError):
            print(f"[debug] unrecognized /drive response: {r.text[:800]}", file=sys.stderr)
            raise

    # ---- support tickets --------------------------------------------------
    def download_ticket(self, path, filename, out_dir, timeout):
        """GET a ticket endpoint and save the octet-stream body as .ltd.
        Returns (ok, message)."""
        os.makedirs(out_dir, exist_ok=True)
        dest = os.path.join(out_dir, filename)
        try:
            r = self.s.get(self.base + path, timeout=(30, timeout), stream=True)
            self._check_auth(r)
            if not r.ok:
                return False, f"{path} -> HTTP {r.status_code}: {r.text[:300]}"
            ctype = r.headers.get("content-type", "")
            if "json" in ctype:
                # Library refused the request; body is a RES_STATUS table.
                try:
                    body = r.json()
                except ValueError:
                    return False, f"{path} -> unexpected JSON: {r.text[:300]}"
                st = self._status_from_json(body)
                msg = st.get("ERRORMESSAGEDB") or st.get("ERRORMESSAGE") \
                    or st.get("ERRORCODE") or json.dumps(body)[:300]
                if not st:
                    print(f"[debug] unrecognized ticket response: {json.dumps(body)[:500]}",
                          file=sys.stderr)
                return False, f"{path} -> {msg}"
            if "octet-stream" not in ctype:
                return False, f"{path} -> unexpected content-type {ctype!r}"
            size = 0
            with open(dest, "wb") as fh:
                for chunk in r.iter_content(1 << 20):
                    fh.write(chunk)
                    size += len(chunk)
            return True, f"{dest} ({size} bytes)"
        except requests.RequestException as e:
            return False, f"{path} -> {e}"


def collect(api, args):
    """List drives, then fetch library + drive tickets in parallel."""
    print("Reading drive inventory...")
    drives = api.get_drives(timeout=120)
    print(f"Library has {len(drives)} drive(s):")
    for d in drives:
        phy = str(d.get("DRIVE_PHY_NUM", "?")).strip()
        msn = str(d.get("DRIVE_MANUF_SERIAL_NO", "?")).strip()
        lsn = str(d.get("DRIVE_SERIAL_NO", "?")).strip()
        lto = d.get("DRIVE_LTO_GEN")
        # DRIVE_LTO_GEN is 0-based in CVTL (deserializer adds 1): 7 -> LTO8.
        gen = f"LTO{int(str(lto).strip()) + 1}" if str(lto).strip().isdigit() else "?"
        cart = str(d.get("CARTRIDGE_LABEL", "")).strip() or "no cartridge"
        fw = str(d.get("DRIVE_PRODUCT_REVISION", "")).strip()
        print(f"  drive {phy}: {gen}, manuf SN {msn}, logical SN {lsn}, fw {fw}, media: {cart}")
    if not drives:
        print("No drives reported; nothing to collect per drive.")

    ts = time.strftime("%Y%m%d_%H%M%S")
    lib_sn = args.serial or f"host_{args.host}"
    jobs = [("/stack/library-plr-ticket", f"library_{lib_sn}_{ts}.ltd")]
    for d in drives:
        phy = str(d.get("DRIVE_PHY_NUM", "")).strip()
        if not phy or not phy.isdigit():
            print(f"[debug] drive without usable DRIVE_PHY_NUM, skipped: {d}", file=sys.stderr)
            continue
        msn = re.sub(r"[^A-Za-z0-9_-]", "", str(d.get("DRIVE_MANUF_SERIAL_NO", "")).strip())
        jobs.append((f"/drive/drive-plr-ticket/{phy}",
                     f"drive{phy}_{msn or 'unknownSN'}_{ts}.ltd"))

    print(f"Fetching {len(jobs)} support ticket(s) in parallel "
          f"(generation can take minutes per ticket)...")
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(api.download_ticket, p, n, args.out, args.timeout): (p, n)
                for p, n in jobs}
        for fut in concurrent.futures.as_completed(futs):
            ok, msg = fut.result()
            print(("  OK  " if ok else "  FAIL") + " " + msg)
            results.append((futs[fut][0], ok))
    failed = [p for p, ok in results if not ok]
    if failed:
        raise RuntimeError(f"{len(failed)} ticket(s) failed: {', '.join(failed)}")


def main():
    ap = argparse.ArgumentParser(
        description="Collect library and drive support tickets from an HPE MSL library.")
    ap.add_argument("--host", required=True, help="library hostname or IP")
    ap.add_argument("--user", default="cvtl",
                    help="REST user (CVTL always uses 'cvtl'; default: %(default)s)")
    ap.add_argument("--out", default="./sticket", help="output directory (default: %(default)s)")
    ap.add_argument("--serial", help="library serial number for the ticket file name "
                                     "(otherwise host_<host> is used)")
    ap.add_argument("--port", type=int, default=3031, help="REST port (default: %(default)s)")
    ap.add_argument("--workers", type=int, default=4,
                    help="parallel ticket downloads (default: %(default)s)")
    ap.add_argument("--timeout", type=int, default=1800,
                    help="read timeout per ticket in seconds (default: %(default)s)")
    ap.add_argument("--verify-tls", action="store_true",
                    help="verify the library's TLS certificate (it is self-signed)")
    a = ap.parse_args()

    pw = os.environ.get("MSL_PASSWORD") or getpass.getpass(f"REST password for {a.user}: ")
    api = MSLRestClient(a.host, a.user, pw, verify=a.verify_tls, port=a.port)
    collect(api, a)


if __name__ == "__main__":
    sys.exit(main())
