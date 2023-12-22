@echo off
chcp 65001
color 0A
setlocal enableextensions enabledelayedexpansion
echo "------------------------------------------------------------------------------------------------------------"
echo "Вы запустили скрипт для сбора информации об аппаратной части серверов HPE Proliant Gen8/Gen9/Gen10 через ILO"
echo "Команды выполняются через интерфейс HPE RESTful API"
echo "Собранная информация записывается в текстовый файл в той же папке, откуда запущен скрипт"
echo "Логины и пароли в текстовый файл не записываются"
echo "------------------------------------------------------------------------------------------------------------"
echo "Выберите режим сканирования интерфейсов ILO"
echo "Укажите "1" для сканирования одного IP-адреса"
echo "Укажите "2" для сканирования диапозона IP-адресов"
set /p s1="Что сканируем:"
:TP
goto TP%s1%
:TP1
echo "---------------------------------"
echo "Сканирование одного IP-адреса ILO"
echo "---------------------------------"
set /p address="Введите IP-адрес ILO сервера:"
set /p user="Введите логин пользователя ILO:"
set /p pass="Введите пароль пользователя ILO:"
set fname=collectedStatus
curl -D result.txt -o result.json -u %user%:%pass% -k -X GET https://%address%/rest/v1/Chassis/1 -H "Content-Type: application/json"
findstr "200" "result.txt" 2>nul >nul && (
echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Server -%address%----- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model, .SerialNumber, .SKU, .Status[], .Bios.Current[], .Oem.Hp.HostOS.OsName, .Oem.Hp.HostOS.OsVersion" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Processors|.Count, .ProcessorFamily, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAM ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/Memory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\memory.txt
for /f "usebackq tokens=*" %%a in ("%~dp0\memory.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/%%~a -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name, .PartNumber, .SizeMB, .MaximumFrequencyMHz, .DIMMTechnology, .DIMMType?, .DIMMStatus" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\memory.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/SmartStorage/ArrayControllers/0 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model?, .SerialNumber?, .InterfaceType?, .SerialNumber, .Status[]?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hp.Battery[]|.ProductName, .Model, .SerialNumber, .Spare" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- HDDs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/SmartStorage/ArrayControllers -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ArraysCtr.txt
for /f "usebackq tokens=*" %%h in ("%~dp0\ArraysCtr.txt") do (
curl -u %user%:%pass% -k -X GET https://%address%/rest/%%~h/DiskDrives -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\disks.txt 
for /f "usebackq tokens=*" %%d in ("%~dp0\disks.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/%%~d -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.CapacityGB?, .Model?, .InterfaceType?, .SerialNumber?,  .Status[]" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
)
del %~dp0\disks.txt
del %~dp0\ArraysCtr.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- NICs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/NetworkAdapters -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ethadp.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\ethadp.txt") do (
curl -u %user%:%pass% -k -X GET https://%address%/rest/%%~e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?, .PartNumber?, .SerialNumber?, .Status[]" >> %~dp0\%fname%.txt
)
del %~dp0\ethadp.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/PCIDevices -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\pcidev.txt 
for /f "usebackq tokens=*" %%t in ("%~dp0\pcidev.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/%%~t -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\pcidev.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCU --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.Model,.PowerCapacityWatts, .SerialNumber, .SparePartNumber, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- FANs --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Chassis/1/Thermal -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Fans[]|.FanName, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- FirmwareInventory --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/FirmwareInventory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Current[]|.[].[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- IML log --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/v1/Systems/1/LogServices/IML/Entries -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".links.Member[].href[6:]" > %~dp0\Entries.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\Entries.txt") do (
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%address%/rest/%%e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.RecordId, .Created, .Message, .Severity" >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
)
del %~dp0\Entries.txt
) || goto TP
del %~dp0\result.txt
del %~dp0\result.json
pause
exit

:TP2
echo "-------------------------------------"
echo "Сканирование диапазона IP-адресов ILO"
echo "-------------------------------------"
echo "Начальный и конечный IP-адреса необходимо вводить по октетам"
set /p ip1="(Начальный IP-адрес диапазона) Укажите первый октет начального IP-адреса (XXX.___.___.___):"
set /p ip2="(Начальный IP-адрес диапазона) Укажите второй октет начального IP-адреса (___.XXX.___.___):"
set /p ip3="(Начальный IP-адрес диапазона) Укажите второй октет начального IP-адреса (___.___.XXX.___):"
set /p ip4="(Начальный IP-адрес диапазона) Укажите второй октет начального IP-адреса (___.___.___.XXX):"
set /p ip5="(Конечный IP-адрес диапазона) Укажите первый октет конечного IP-адреса (YYY.___.___.___):"
set /p ip6="(Конечный IP-адрес диапазона) Укажите первый октет конечного IP-адреса (___.YYY.___.___):"
set /p ip7="(Конечный IP-адрес диапазона) Укажите первый октет конечного IP-адреса (___.___.YYY.___):"
set /p ip8="(Конечный IP-адрес диапазона) Укажите первый октет конечного IP-адреса (___.___.___.YYY):"
set /p user="Укажите логин пользователя ILO:"
set /p pass="Укажите пароль пользователя ILO:"
set fname=collectedrange
for /L %%a in (%ip4%,1,%ip8%) do (curl -m 2 -D %~dp0\result.txt -k -u %user%:%pass% -X GET https://%ip1%.%ip2%.%ip3%.%%a/rest/v1 -H "Content-Type:application/json" | %~dp0\jq-win64.exe -r . | find "iLO" > nul
if !errorlevel!==0 (echo %ip1%.%ip2%.%ip3%.%%a>>%~dp0\iprang.txt)
)

for /f "usebackq tokens=*" %%k in ("%~dp0\iprang.txt") do (
curl -u %user%:%pass% -D %~dp0\result.txt -o %~dp0\result.json -k -X GET https://%%~k/rest/v1/Chassis/1 -H "Content-Type: application/json"
findstr "200" "result.txt" 2>nul >nul && (
echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Server -------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Chassis/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Model?, .SKU?, .SerialNumber?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Processors|.Count, .ProcessorFamily, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAM ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1/Memory -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\memory.txt
for /f "usebackq tokens=*" %%a in ("%~dp0\memory.txt") do (
curl -u %user%:%pass% -k -X GET https://%%~k/rest/%%~a -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name, .PartNumber, .SizeMB, .MaximumFrequencyMHz, .DIMMTechnology, .DIMMType?, .DIMMStatus" >> %~dp0\%fname%.txt
)
del %~dp0\memory.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1/SmartStorage/ArrayControllers/0 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model?, .SerialNumber?, .InterfaceType?, .SerialNumber?, .Status[]" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hp.Battery[]|.ProductName, .Model, .SerialNumber, .Spare" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- HDDs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1/SmartStorage/ArrayControllers -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ArraysCtr.txt
for /f "usebackq tokens=*" %%h in ("%~dp0\ArraysCtr.txt") do (
curl -u %user%:%pass% -k -X GET https://%%~k/rest/%%~h/DiskDrives -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\disks.txt 
for /f "usebackq tokens=*" %%d in ("%~dp0\disks.txt") do (
curl -u %user%:%pass% -k -X GET https://%%~k/rest/%%~d -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.CapacityGB?, .Model?, .InterfaceType?, .SerialNumber?, .Status[]" >> %~dp0\%fname%.txt
)
)
del %~dp0\disks.txt
del %~dp0\ArraysCtr.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- NICs ---------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1/NetworkAdapters -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\ethadp.txt
for /f "usebackq tokens=*" %%e in ("%~dp0\ethadp.txt") do (
curl -u %user%:%pass% -k -X GET https://%%~k/rest/%%~e -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?, .PartNumber?, .SerialNumber?" >> %~dp0\%fname%.txt
)
del %~dp0\ethadp.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo &echo.&echo.--- PowerSupplies ------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.SerialNumber, .SparePartNumber, .PowerCapacityWatts, .Model" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -u %user%:%pass% -k -X GET https://%%~k/rest/v1/Systems/1/PCIDevices -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r .links.Member[].href[6:] >> %~dp0\pcidev.txt 
for /f "usebackq tokens=*" %%t in ("%~dp0\pcidev.txt") do (
curl -u %user%:%pass% -k -X GET https://%%~k/rest/%%~t -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Name?" >> %~dp0\%fname%.txt
)
del %~dp0\pcidev.txt
) || goto TP
del %~dp0\result.txt
del %~dp0\result.json
)
del %~dp0\iprang.txt
pause
exit
