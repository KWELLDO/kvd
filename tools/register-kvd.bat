@echo off
REM ===== KVD File Association Registration =====
REM Run this script as Administrator to register .kvd file associations
REM This will make .kvd files open with the KVD viewer on double-click

echo Registering KVD file type...

REM Register the extension
assoc .kvd=KWD.KVD.Document 2>nul
if %errorlevel% neq 0 (
    echo [WARN] assoc may require admin. Trying registry...
    reg add "HKCU\Software\Classes\.kvd" /ve /d "KWD.KVD.Document" /f >nul
)

REM Register the progid and open command
ftype KWD.KVD.Document="D:\KWD\kvd\tools\kvd-open.bat" "%%1" 2>nul
if %errorlevel% neq 0 (
    reg add "HKCU\Software\Classes\KWD.KVD.Document\shell\open\command" /ve /d "`"D:\KWD\kvd\tools\kvd-open.bat`" `"%%1`"" /f >nul
)

REM Add "View KVD History" context menu
reg add "HKCU\Software\Classes\KWD.KVD.Document\shell\Show-KvdHistory" /ve /d "View KVD &History" /f >nul
reg add "HKCU\Software\Classes\KWD.KVD.Document\shell\Show-KvdHistory\command" /ve /d "pwsh -NoProfile -ExecutionPolicy Bypass -Command `"& { Import-Module 'D:\KWD\kvd\tools\KvdModule.psm1'; Show-KvdHistoryView -Path '%%1' }`"" /f >nul

REM Also register HKCU\Software\Classes\.kvd for current user
reg add "HKCU\Software\Classes\.kvd" /ve /d "KWD.KVD.Document" /f >nul

echo Done!
echo Now double-click any .kvd file to open with KVD viewer.
echo Right-click a .kvd file and select "View KVD History" to see full history.
pause
