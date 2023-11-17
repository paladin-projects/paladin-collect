# paladin-collect
Scripts for collection of configuration and diagnostics from hardware

# About
This repo contains scripts that we use to collect configuration and diagnostics information from Customers' hardware

# nympho
Nympho (mis-spelled Nimble info) is the script for Nimble OS which runs most of commands to collect detailed array configuration and diagnostics information

Skipped commands: ? help timezone halt reboot setup migration failover stats version vmwplugin

## Usage
1. From a Linux box:
`ssh admin@<nimble> < nympho > nympho.out`

1. In PuTTY open the connection, start loggin, copy-paste script body with right-click. (Session may hang at the end, but it is ok)

1. With full PuTTY distributive installed, or with Plink installed:
`plink.exe -ssh admin@<nimble> < nympho > nympho.out`

# ScanservConfig_Range.bat, ScanservConfig_Single.bat, ScanservHealth_Single.bat
Collect information from iLO via iLO RESTful interface (Redfish)

## Dependecies
Scanserv* scripts depend on jq utility. Get it from <https://jqlang.github.io/jq/>.

## Usage
1. In Windows press Win+R.
1. Type `cmd` and press Enter.
1. Change directory to where you downloaded scripts.
1. Make sure jq-win64.exe is in the same folder.
1. Run script by typing its name. The script will ask you to enter iLO IP address, login, password. Results are saved to `collected*` file.
