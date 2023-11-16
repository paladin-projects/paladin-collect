@echo off
chcp 65001
color 0A
setlocal enableextensions enabledelayedexpansion

:TP
set /p address="Введите IP-адрес:"
set /p user="Введите логин:"
set /p pass="Введите пароль:"
set fname=collectedStatus
cmd /c  
curl -D result.txt -o result.json -k -X GET https://%user%:%pass%@%address%/rest/v1/Chassis/1 -H "Content-Type: application/json"
findstr "200" "result.txt" 2>nul >nul && (
echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Server -%address%----- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model, .SerialNumber, .SKU, .Status[], .Bios.Current[], .Oem.Hp.HostOS.OsName, .Oem.Hp.HostOS.OsVersion" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Processors|.Count, .ProcessorFamily, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAM ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/Memory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\memory.txt
for /f "usebackq tokens=*" %%a in ("%~dp0\memory.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/%%~a -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name, .PartNumber, .SizeMB, .MaximumFrequencyMHz, .DIMMTechnology, .DIMMType?, .DIMMStatus" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\memory.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/SmartStorage/ArrayControllers/0 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model?, .SerialNumber?, .InterfaceType?, .SerialNumber, .Status[]?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hp.Battery[]|.ProductName, .Model, .SerialNumber, .Spare" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- HDDs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/SmartStorage/ArrayControllers -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ArraysCtr.txt
for /f "usebackq tokens=*" %%h in ("%~dp0\ArraysCtr.txt") do (
curl -k -X GET https://%user%:%pass%@%address%/rest/%%~h/DiskDrives -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\disks.txt 
for /f "usebackq tokens=*" %%d in ("%~dp0\disks.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/%%~d -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.CapacityGB?, .Model?, .InterfaceType?, .SerialNumber?,  .Status[]" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
)
del %~dp0\disks.txt
del %~dp0\ArraysCtr.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- NICs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/NetworkAdapters -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ethadp.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\ethadp.txt") do (
curl -k -X GET https://%user%:%pass%@%address%/rest/%%~e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?, .PartNumber?, .SerialNumber?, .Status[]" >> %~dp0\%fname%.txt
)
del %~dp0\ethadp.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/PCIDevices -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\pcidev.txt 
for /f "usebackq tokens=*" %%t in ("%~dp0\pcidev.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/%%~t -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\pcidev.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCU --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.Model,.PowerCapacityWatts, .SerialNumber, .SparePartNumber, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- FANs --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Chassis/1/Thermal -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Fans[]|.FanName, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- FirmwareInventory --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/FirmwareInventory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Current[]|.[].[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- IML log --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/v1/Systems/1/LogServices/IML/Entries -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".links.Member[].href[6:]" > %~dp0\Entries.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\Entries.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/rest/%%e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.RecordId, .Created, .Message, .Severity" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\Entries.txt
) || goto TP
del %~dp0\result.txt
del %~dp0\result.json
pause
exit