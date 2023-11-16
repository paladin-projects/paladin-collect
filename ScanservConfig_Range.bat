@echo off
chcp 65001
color 0A
setlocal enableextensions enabledelayedexpansion
echo "Внимание!!! Начальный и конечный IP адреса диапазона необходимо вводить по одному октету"
echo "Например для IP 192.168.0.1 : 192-первый октет, 168-второй октет, 0-третий октет, 1-четвертый октет"
:TP
echo "Необходимо указать НАЧАЛЬНЫЙ IP адрес диапазона --->"
set /p ip1="Введите первый октет: "
set /p ip2="Введите второй октет: "
set /p ip3="Введите третий октет: "
set /p ip4="Введите четвертый октет:"
echo "---> Необходимо указать КОНЕЧНЫЙ IP адрес диапазона"
set /p ip5="Введите первый октет: "
set /p ip6="Введите второй октет: "
set /p ip7="Введите третий октет: "
set /p ip8="Введите четвертый октет:"
set /p user="Введите логин для входа в ILO: "
set /p pass="Введите пароль для входа в ILO: "
set fname=collectedrange
for /L %%a in (%ip4%,1,%ip8%) do (curl -m 2 -k -X GET https://%user%:%pass%@%ip1%.%ip2%.%ip3%.%%a/rest/v1 -H "Content-Type:application/json" | %~dp0\jq-win64.exe -r . | find "iLO" > nul
if !errorlevel!==0 (echo %ip1%.%ip2%.%ip3%.%%a>>%~dp0\iprang.txt)
)

for /f "usebackq tokens=*" %%k in ("%~dp0\iprang.txt") do (
cmd /c  
curl -D result.txt -o result.json -k -X GET https://%user%:%pass%@%%~k/rest/v1/Chassis/1 -H "Content-Type: application/json"
findstr "200" "result.txt" 2>nul >nul && (
echo &echo.&echo.>> %~dp0\%fname%.txt
echo -- Server ILO IP %%~k -- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Chassis/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Model?, .SKU?, .SerialNumber?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Processors|.Count, .ProcessorFamily" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAM ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1/Memory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\memory.txt
for /f "usebackq tokens=*" %%a in ("%~dp0\memory.txt") do (
curl -k -X GET https://%user%:%pass%@%%~k/rest/%%~a -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name, .PartNumber, .SizeMB, .MaximumFrequencyMHz, .DIMMTechnology, .DIMMType?" >> %~dp0\%fname%.txt
)
del %~dp0\memory.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1/SmartStorage/ArrayControllers/0 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model?, .SerialNumber?, .InterfaceType?, .SerialNumber?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hp.Battery[]|.ProductName, .Model, .SerialNumber, .Spare" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- HDDs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1/SmartStorage/ArrayControllers -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ArraysCtr.txt
for /f "usebackq tokens=*" %%h in ("%~dp0\ArraysCtr.txt") do (
curl -k -X GET https://%user%:%pass%@%%~k/rest/%%~h/DiskDrives -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\disks.txt 
for /f "usebackq tokens=*" %%d in ("%~dp0\disks.txt") do (
curl -k -X GET https://%user%:%pass%@%%~k/rest/%%~d -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.CapacityGB?, .Model?, .InterfaceType?, .SerialNumber?" >> %~dp0\%fname%.txt
)
)
del %~dp0\disks.txt
del %~dp0\ArraysCtr.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- NICs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1/NetworkAdapters -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ethadp.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\ethadp.txt") do (
curl -k -X GET https://%user%:%pass%@%%~k/rest/%%~e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?, .PartNumber?, .SerialNumber?" >> %~dp0\%fname%.txt
)
del %~dp0\ethadp.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo &echo.&echo.--- PowerSupplies ------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.SerialNumber, .SparePartNumber, .PowerCapacityWatts, .Model" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%%~k/rest/v1/Systems/1/PCIDevices -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\pcidev.txt 
for /f "usebackq tokens=*" %%t in ("%~dp0\pcidev.txt") do (
curl -k -X GET https://%user%:%pass%@%%~k/rest/%%~t -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?" >> %~dp0\%fname%.txt
)
del %~dp0\pcidev.txt
) || goto TP
del %~dp0\result.txt
del %~dp0\result.json
)
del %~dp0\iprang.txt
pause
exit