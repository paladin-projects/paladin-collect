@echo off
chcp 65001
color 0A
:TP
set /p address="Введите IP адрес ILO сервера в обычном формате:"
set /p user="Введите логин для входа в ILO:"
set /p pass="Введите пароль для входа в ILO:"
set fname=collected
cmd /c
curl -D result.txt -o result.json -k -X GET https://%user%:%pass%@%address%/redfish/v1/Chassis/1 -H "Content-Type: application/json"
findstr "200" "result.txt" 2>nul >nul && (
echo &echo.&echo.>> %~dp0\%fname%.txt
echo -- Server ILO IP %address% -- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/redfish/v1/Chassis/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Model?, .SKU?, .SerialNumber?" >> %~dp0\%fname%.txt
)

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- CPU ----------------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/redfish/v1/Systems/1 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".ProcessorSummary|.Count, .Model" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Memory ---------------------- >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt
curl -s -k -X GET "https://%user%:%pass%@%address%/redfish/v1/Systems/1/Memory/?$expand=." -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Oem.Hpe.MemoryList[] as $cpu | \"--- CPU \($cpu.BoardCpuNumber) DIMMs (Frequency: \($cpu.BoardOperationalFrequency) MHz, Total size: \($cpu.BoardTotalMemorySize) MiB) ---\", (.Members[] | select(.MemoryLocation.Socket == $cpu.BoardCpuNumber) | \"Name: \(.Name)\", \"PartNumber: \(.PartNumber)\", \"SerialNumber: \(.SerialNumber)\", \"CapacityMiB: \(.CapacityMiB)\", \"OperatingSpeedMhz: \(.OperatingSpeedMhz?)\", \"MemoryDeviceType: \(.MemoryDeviceType?)\", \"MemoryType: \(.MemoryType)\", \"\"), \"\"" >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- RAID Controllers ---------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/redfish/v1/Systems/1/SmartStorage/ArrayControllers/0 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".|.Model?, .SerialNumber?, .LocationFormat?" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Battery/Capacitor --------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/redfish/v1/Systems/1/SmartStorage/ArrayControllers/0 -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r "if .BackupPowerSourceStatus == \"NotPresent\" then \"Battery: Not Present\" else \"Battery: Present (\( .BackupPowerSourceStatus))\" end" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Physical drives ---------------------- >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt
curl -k -X GET "https://%user%:%pass%@%address%/redfish/v1/Systems/1/SmartStorage/ArrayControllers" -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Members[].\"@odata.id\" | ltrimstr(\"/redfish/v1/\")" >> %~dp0\controllers.txt
for /f "usebackq tokens=*" %%c in ("%~dp0\controllers.txt") do (
    echo Controller: %%c >> %~dp0\%fname%.txt
    curl -s -k -X GET "https://%user%:%pass%@%address%/redfish/v1/%%c/DiskDrives/?$expand=." -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Members[] | [.Id, .CapacityGB?, .Model?, .InterfaceType?, .InterfaceSpeedMbps?, .MediaType?, .SerialNumber?, .Location?, .FirmwareVersion.Current.VersionString?] | @tsv" >> %~dp0\%fname%.txt
    echo.>> %~dp0\%fname%.txt
)
del %~dp0\controllers.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- Network adapters ---------------------- >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt
curl -k -X GET "https://%user%:%pass%@%address%/redfish/v1/Chassis/1/NetworkAdapters/?$expand=." -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Members[] | .Name?, .PartNumber?, .SerialNumber?, .SKU?, \"\"" >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo &echo.&echo.--- PowerSupplies ------------- >> %~dp0\%fname%.txt
echo &echo.&echo.>> %~dp0\%fname%.txt
curl -k -X GET https://%user%:%pass%@%address%/redfish/v1/Chassis/1/Power -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".PowerSupplies[]|.SerialNumber, .SparePartNumber, .PowerCapacityWatts, .Model, \"\"" >> %~dp0\%fname%.txt

echo &echo.&echo.>> %~dp0\%fname%.txt
echo --- PCI Devices --------------- >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt
curl -k -X GET "https://%user%:%pass%@%address%/redfish/v1/Systems/1/PCIDevices/?$expand=." -H "Content-Type: application/json" | %~dp0\jq-win64.exe -r ".Members[] | [.Id, .Name?] | @tsv" >> %~dp0\%fname%.txt
echo.>> %~dp0\%fname%.txt

del %~dp0\result.txt
del %~dp0\result.json
pause
exit