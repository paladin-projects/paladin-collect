# paladin-collect
Scripts for collection of configuration and dignostics from hardware

# About
This repo contains scripts that we use to collect configuration and diagnostics information from Customers' hardware

# nympho
Nimble Storage Info Collector Script

# Nimble Storage Info Collector Script
Nympho (mis-spelled Nimble info) is the script for Nimble OS which runs most of commands to collect detailed array configuration and diagnostics information

Skipped commands: ? help timezone halt reboot setup migration failover stats version vmwplugin

# Usage
1. From a Linux box:
`ssh admin@<nimble> < nympho > nympho.out`

1. In PuTTY open the connection, start loggin, copy-paste script body with right-click. (Session may hang at the end, but it is ok)

1. With full PuTTY distributive installed, or with Plink installed:
`plink.exe -ssh admin@<nimble> < nympho > nympho.out`
