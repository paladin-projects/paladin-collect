@echo off
chcp 65001
color 0A
setlocal enableextensions enabledelayedexpansion
echo "Введите 1 - для сканирования одного ilo"
echo "Введите 2 - для сканирования диапозона адресов ilo"
set /p s1="Выберите режим:"
:TP
goto TP%s1%
:TP1
set /p address="Введите IP-адрес:"
set /p user="Введите логин:"
set /p pass="Введите пароль:"
set fname=collectedStatus
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Chassis/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r "." | FIND /I "SerialNumber" >nul
if !ERRORLEVEL!==0 (goto start) else (goto TP)
:start

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Server -%address%----- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model, .SerialNumber, .SKU, .Status[], .Bios.Current[], .Oem.Hp.HostOS.OsName, .Oem.Hp.HostOS.OsVersion" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Processors|.Count, .ProcessorFamily, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAM ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1/Memory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\memory.txt
for /f "usebackq tokens=*" %%a in ("%~dp0\memory.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/%%~a -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name, .PartNumber, .SizeMB, .MaximumFrequencyMHz, .DIMMTechnology, .DIMMType, .DIMMStatus" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\memory.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1/SmartStorage/ArrayControllers -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:-1] >> %~dp0\ArraysCtr.txt
for /f "usebackq tokens=*" %%b in ("%~dp0\ArraysCtr.txt") do (
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/%%~b -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model, .SerialNumber, .CacheMemorySizeMiB, .Status[]" >> %~dp0\%fname%.txt
)
echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hp.Battery[]|.ProductName, .Model, .SerialNumber, .Spare, .Condition" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- HDDs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
for /f "usebackq tokens=*" %%h in ("%~dp0\ArraysCtr.txt") do (
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/%%~h/DiskDrives -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\disks.txt 
for /f "usebackq tokens=*" %%d in ("%~dp0\disks.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/%%~d -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.CapacityGB, .Model, .InterfaceType, .SerialNumber,  .Status[]" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
)
del %~dp0\ArraysCtr.txt
del %~dp0\disks.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- NICs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1/NetworkAdapters -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\ethadp.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\ethadp.txt") do (
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/%%~e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?, .PartNumber, .SerialNumber, .Status[]" >> %~dp0\%fname%.txt
)
del %~dp0\ethadp.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -L -X GET https://%address%/redfish/v1/Systems/1/PCIDevices -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\pcidev.txt 
for /f "usebackq tokens=*" %%t in ("%~dp0\pcidev.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/%%~t -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\pcidev.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCU --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.Model,.PowerCapacityWatts, .SerialNumber, .SparePartNumber, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- FANs --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Chassis/1/Thermal -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Fans[]|.FanName, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- FirmwareInventory --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1/FirmwareInventory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Current[]|.[].[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- IML log --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1/LogServices/IML/Entries -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Total" > %~dp0\count.tmp
for /f "usebackq tokens=*" %%o in ("%~dp0\count.tmp") do (
set /a count1=%%~o
set /a count2=%%~o-30
)
for /L %%y in (%count1%,-1,%count2%) do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%address%/redfish/v1/Systems/1/LogServices/IML/Entries/%%y -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Id, .RecordId, .Created, .Message, .Severity" >> %fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\count.tmp
pause
exit

:TP2
echo "Данный скрипт не может создать форму для ввода IP адреса, необходимо внести все значения поочерёдно"
echo "10.0.0.1 - это (первое значение).(второе значение).(третье значение).(четвертое значение)"
set /p ip1="Введите первое значение начала диапозона IP адрессов:"
set /p ip2="Введите второе значение начала диапозона IP адрессов:"
set /p ip3="Введите третье значение начала диапозона IP адрессов:"
set /p ip4="Введите четвертое значение начала диапозона IP адрессов:"
set /p ip5="Введите первое значение конца диапозона IP адрессов:"
set /p ip6="Введите второе значение конца диапозона IP адрессов:"
set /p ip7="Введите третье значение конца диапозона IP адрессов:"
set /p ip8="Введите четвертое значение конца диапозона IP адрессов:"
set /p user="Введите логин:"
set /p pass="Введите пароль:"
set fname=collectedrange
for /L %%a in (%ip4%,1,%ip8%) do (curl -m 2 -D %~dp0\result.txt -k -L -u %user%:%pass% -X GET https://%ip1%.%ip2%.%ip3%.%%a/redfish/v1 -H "Content-Type:application/json" | %~dp0\jq-win64.exe -r . | find "iLO" > nul
if !errorlevel!==0 (echo %ip1%.%ip2%.%ip3%.%%a>>%~dp0\iprang.txt)
)

for /f "usebackq tokens=*" %%k in ("%~dp0\iprang.txt") do (
curl -u %user%:%pass% -D %~dp0\result.txt -o %~dp0\result.json -k -L -s -X GET https://%%~k/redfish/v1/Chassis/1 -H "Content-Type: application/json"
findstr "200" "result.txt" 2>nul >nul && (
echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Server -------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Chassis/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Model?, .SKU?, .SerialNumber?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Processors|.Count, .ProcessorFamily, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAM ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -L -X GET https://%%~k/redfish/v1/Systems/1/Memory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\memory.txt
for /f "usebackq tokens=*" %%a in ("%~dp0\memory.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/%%~a -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name, .PartNumber, .SizeMB, .MaximumFrequencyMHz, .DIMMTechnology, .DIMMType?, .DIMMStatus" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\memory.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Systems/1/SmartStorage/ArrayControllers -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:-1] >> %~dp0\ArraysCtr.txt
for /f "usebackq tokens=*" %%b in ("%~dp0\ArraysCtr.txt") do (
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/%%~b -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model?, .SerialNumber, .CacheMemorySizeMiB, .Status[]" >> %~dp0\%fname%.txt
)

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hp.Battery[]|.ProductName, .Model, .SerialNumber, .Spare, .Condition" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- HDDs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
for /f "usebackq tokens=*" %%h in ("%~dp0\ArraysCtr.txt") do (
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/%%~h/DiskDrives -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\disks.txt 
for /f "usebackq tokens=*" %%d in ("%~dp0\disks.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/%%~d -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.CapacityGB?, .Model?, .InterfaceType?, .SerialNumber?, .Status[]" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
)
del %~dp0\disks.txt
del %~dp0\ArraysCtr.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- NICs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Systems/1/NetworkAdapters -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\ethadp.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\ethadp.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/%%~e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?, .PartNumber?, .SerialNumber?" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\ethadp.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo &echo.&echo.--- PowerSupplies ------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.SerialNumber, .SparePartNumber, .PowerCapacityWatts, .Model" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/v1/Systems/1/PCIDevices -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[9:] >> %~dp0\pcidev.txt 
for /f "usebackq tokens=*" %%t in ("%~dp0\pcidev.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -L -s -X GET https://%%~k/redfish/%%~t -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\pcidev.txt
) || goto TP
del %~dp0\result.txt
del %~dp0\result.json
)
del %~dp0\iprang.txt
pause
exit
