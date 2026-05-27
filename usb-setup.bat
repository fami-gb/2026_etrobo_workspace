@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
set "POWERSHELL_BIN=powershell.exe"
set "WAIT_ON_EXIT=0"

echo %CMDCMDLINE% | findstr /I /R " /c " >nul 2>&1
if not errorlevel 1 set "WAIT_ON_EXIT=1"
if /I "%~1"=="--pause" set "WAIT_ON_EXIT=1"
if /I "%~1"=="--no-pause" set "WAIT_ON_EXIT=0"

where "%POWERSHELL_BIN%" >nul 2>&1
if errorlevel 1 (
    >&2 echo PowerShell が見つかりません: %POWERSHELL_BIN%
    set "EXIT_CODE=2"
    goto :finalize
)

echo LEGO USBデバイスを検出中...
set "USB_BUSID="
for /f "usebackq delims=" %%I in (`%POWERSHELL_BIN% -NoProfile -NonInteractive -Command "$d=(usbipd state|ConvertFrom-Json).Devices|Where-Object{$_.Description -match 'LEGO|DFU|SPIKE|MINDSTORMS' -or $_.InstanceId -match 'VID_0694'}|Sort-Object BusId; if(-not $d){exit 3}; $s=@($d|Where-Object{$_.Description -match 'DFU'}); if($s){$s[0].BusId}else{$d[0].BusId}"`) do if not "%%I"=="" if not defined USB_BUSID set "USB_BUSID=%%I"

if not defined USB_BUSID (
    >&2 echo BUSID自動検出に失敗しました。LEGOデバイスを接続しDFUモードを確認してください。
    set "EXIT_CODE=3"
    goto :finalize
)

echo USB_BUSID=%USB_BUSID%

usbipd bind --busid %USB_BUSID% >nul 2>&1
if errorlevel 1 (
    >&2 echo [info] bind スキップ（既にbind済みの可能性）
)

start /min "" usbipd attach --wsl --busid %USB_BUSID% --auto-attach >nul 2>&1
if errorlevel 1 (
    >&2 echo attachに失敗しました。管理者権限やusbipdの状態を確認してください。
    set "EXIT_CODE=4"
    goto :finalize
)

echo USB attach 完了 (BUSID=%USB_BUSID%)
set "EXIT_CODE=0"

:finalize
if /I "%WAIT_ON_EXIT%"=="1" (
    echo.
    echo 終了するには何かキーを押してください...
    pause >nul
)
exit /b %EXIT_CODE%
