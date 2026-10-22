#!/usr/bin/env python3
"""
Vibe-coded with Claude.

Request an InSplore (health data) collection on an HPE Primera / Alletra MP
array through the web UI's REST API (/api/v3), wait for the resulting file,
and download it.

Endpoints reverse-engineered from the UI bundle:
  POST   /api/v3/credentials   {user, password, isArrayUser: true}   -> session cookie
  POST   /api/v3/telemetry     {action: INSPLORECOLLECTION, parameters: {...}}
  GET    /api/v3/files         -> list of files (uid, fileName, fileType, fileSize, fileModTime.ms)
  POST   /api/v3/files         multipart, field "json" =
                               {"action":"FILEDOWNLOAD","parameters":"{\"uIDs\":[...]}"}
  DELETE /api/v3/credentials   -> logout

Requires python3-requests.

Usage:
  ./get-insplore.py --host 10.0.0.10 --user 3paradm
  (password is read from $PRIMERA_PASSWORD or prompted)
"""
import argparse
import getpass
import json
import os
import re
import requests
import sys
import time
import urllib3
from urllib.parse import quote


class PrimeraUI:
    def __init__(self, host, verify=False):
        self.base = f"https://{host}"
        self.s = requests.Session()
        self.s.verify = verify
        # The array rejects requests (even GETs) without a JSON media type.
        self.s.headers.update({"Accept": "application/json",
                               "Content-Type": "application/json"})
        if not verify:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    def _json(self, method, path, body=None, **kw):
        for attempt in range(6):
            r = self.s.request(method, self.base + path, json=body, timeout=120, **kw)
            if r.status_code != 429:
                break
            time.sleep(2 * (attempt + 1))  # array rate limit: back off and retry
        if not r.ok:
            raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:500]}")
        return r.json() if r.content and "json" in r.headers.get("content-type", "") else None

    def login(self, user, password):
        # Session is cookie based (the UI uses credentials: "same-origin").
        resp = self._json("POST", "/api/v3/credentials",
                          # The UI sends the password as a list of characters
                          # (password.split("")), not a plain string.
                          {"user": user, "password": list(password), "isArrayUser": True})
        # If the array also returns a token, send it along.
        if isinstance(resp, dict):
            for k in ("token", "sessionKey", "Authorization"):
                if resp.get(k):
                    self.s.headers["Authorization"] = resp[k]
        return resp

    def logout(self):
        try:
            self.s.delete(self.base + "/api/v3/credentials", timeout=30)
        except requests.RequestException:
            pass

    # ---- insplore -------------------------------------------------------
    def start_insplore(self, cli=True, node=True, toc=True, force=False):
        """Options map to the UI checkboxes: clidata / nodedata / tocdata.
        force=False -> SkipIfUpdateInProgress=True (UI default)."""
        options = [o for o, on in (("clidata", cli), ("nodedata", node), ("tocdata", toc)) if on]
        payload = {
            "action": "INSPLORECOLLECTION",
            "parameters": {"Options": options, "SkipIfUpdateInProgress": not force},
        }
        return self._json("POST", "/api/v3/telemetry", payload)

    # ---- files ----------------------------------------------------------
    def list_files(self):
        data = self._json("GET", "/api/v3/files")
        raw = data
        if isinstance(data, dict):
            for key in ("members", "items", "files"):
                if key in data:
                    data = data[key]
                    break
            else:
                data = []
        out = []
        for item in data or []:
            if isinstance(item, str):
                # The array returns bare file names; use the name as uid too.
                item = {"uid": item, "fileName": item}
            if isinstance(item, dict):
                item.setdefault("fileName", item.get("uid", ""))
                out.append(item)
        if not out and raw:
            print(f"[debug] unrecognized /api/v3/files response: {json.dumps(raw)[:800]}",
                  file=sys.stderr)
        return out

    def wait_for_task(self, resp, timeout=3600, poll=10):
        """Poll the UI task created by the request until it reaches a final state.
        Statuses seen in the UI: STATE_FINISHED / STATE_FAILED / STATE_CANCELED
        (anything else, e.g. active/queued, means still running)."""
        uri = resp.get("resourceUri") if isinstance(resp, dict) else None
        if not uri:
            print(f"[debug] no task URI in response: {json.dumps(resp)[:500]}", file=sys.stderr)
            return None
        print(f"Task: {uri}")
        deadline, last = time.time() + timeout, None
        while time.time() < deadline:
            t = self._json("GET", uri) or {}
            status = t.get("status")
            if status != last:
                print(f"Task status: {status}")
                last = status
            if status == "STATE_FINISHED":
                return t
            if status in ("STATE_FAILED", "STATE_CANCELED", "STATE_CANCELLED"):
                details = t.get("detailsMap") or {}
                msg = ""
                if isinstance(details, dict) and details:
                    msg = (details[sorted(details, key=lambda k: int(k) if str(k).isdigit() else 0)[-1]]
                           or {}).get("message", "")
                raise RuntimeError(f"insplore task {status}: {msg or json.dumps(t)[:500]}")
            time.sleep(poll)
        raise TimeoutError("insplore task did not finish in time")

    def get_file(self, uid):
        """Details of one file (fileType, fileSize, fileModTime...)."""
        d = self._json("GET", "/api/v3/files/" + quote(uid, safe=""))
        return d if isinstance(d, dict) else {}

    def wait_for_insplore(self, known_uids, started_ms, timeout=3600, poll=15):
        """Wait for a NEW file whose fileType is exactly 'insplore'."""
        deadline = time.time() + timeout
        inspected = {}  # uid -> fileType (details are fetched once per new file)
        while time.time() < deadline:
            for f in self.list_files():
                uid = f["uid"]
                if uid in known_uids:
                    continue
                if uid not in inspected:
                    d = self.get_file(uid)
                    inspected[uid] = d.get("fileType")
                    if "fileType" not in d:
                        print(f"[debug] details of {uid} have no fileType: "
                              f"{json.dumps(d)[:500]}", file=sys.stderr)
                    else:
                        print(f"New file {uid}: type={d['fileType']}", file=sys.stderr)
                    f.update(d)
                    f["uid"] = d.get("uid", uid)
                    if d.get("fileType") == "insplore":
                        return f
            time.sleep(poll)
        raise TimeoutError("insplore file did not appear in time")

    def wait_until_stable(self, uid, poll=10, rounds=3):
        """File may still be growing; wait until size stops changing."""
        last, same = None, 0
        while same < rounds:
            cur = self.get_file(uid).get("fileSize")
            same = same + 1 if cur is not None and cur == last else 0
            last = cur
            time.sleep(poll)

    def download(self, uids, out_dir):
        os.makedirs(out_dir, exist_ok=True)
        form = {"action": "FILEDOWNLOAD", "parameters": json.dumps({"uIDs": list(uids)})}
        # Browser form posts multipart/form-data with a single field named "json".
        r = self.s.post(self.base + "/api/v3/files",
                        files={"json": (None, json.dumps(form))},
                        # None removes the session's JSON Content-Type so requests
                        # can set multipart/form-data with its boundary.
                        headers={"Accept": "*/*", "Content-Type": None},
                        stream=True, timeout=(30, 600))
        if not r.ok:
            raise RuntimeError(f"download failed {r.status_code}: {r.text[:500]}")
        cd = r.headers.get("content-disposition", "")
        m = re.search(r'filename\*?=(?:UTF-8\'\')?"?([^";]+)"?', cd)
        name = m.group(1) if m else f"insplore_{int(time.time())}.bin"
        path = os.path.join(out_dir, os.path.basename(name))
        with open(path, "wb") as fh:
            for chunk in r.iter_content(1 << 20):
                fh.write(chunk)
        return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--user", default="3paradm")
    ap.add_argument("--out", default="./insplore")
    ap.add_argument("--no-cli", action="store_true")
    ap.add_argument("--no-node", action="store_true")
    ap.add_argument("--no-toc", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="collect even if a software update is in progress")
    ap.add_argument("--timeout", type=int, default=3600)
    ap.add_argument("--verify-tls", action="store_true")
    a = ap.parse_args()

    pw = os.environ.get("PRIMERA_PASSWORD") or getpass.getpass(f"Password for {a.user}: ")
    api = PrimeraUI(a.host, verify=a.verify_tls)
    api.login(a.user, pw)
    try:
        known = {f.get("uid") for f in api.list_files()}
        started = int(time.time() * 1000)
        print("Requesting insplore collection...")
        resp = api.start_insplore(not a.no_cli, not a.no_node, not a.no_toc, a.force)
        print("Waiting for the collection task to finish (this can take a long time)...")
        task = api.wait_for_task(resp, timeout=a.timeout)
        # Task is done: the file should be there now (short grace period only).
        print("Task finished, looking for the insplore file...")
        # without a task to track, fall back to waiting for the file itself
        f = api.wait_for_insplore(known, started, timeout=300 if task else a.timeout)
        print(f"Found {f.get('fileName')} ({f.get('fileSize')} bytes), waiting for it to finish...")
        api.wait_until_stable(f["uid"])
        path = api.download([f["uid"]], a.out)
        print("Saved:", path)
    finally:
        api.logout()


if __name__ == "__main__":
    sys.exit(main())
