@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"

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

pushd "%REPO_ROOT%" >nul 2>&1
if errorlevel 1 (
    >&2 echo 作業ディレクトリへ移動できません: %REPO_ROOT%
    set "EXIT_CODE=2"
    goto :finalize
)

echo LEGO 名を含むUSBデバイスを自動検出します...
set "USB_BUSID="
for /f "usebackq delims=" %%I in (`%POWERSHELL_BIN% -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $state = usbipd state ^| ConvertFrom-Json; $lego = @($state.Devices ^| Where-Object { $_.Description -match 'LEGO' } ^| Sort-Object BusId); if ($lego.Count -eq 0) { Write-Error 'Description に LEGO を含むUSBデバイスが見つかりませんでした。'; exit 3 }; $dfu = @($lego ^| Where-Object { $_.Description -match 'DFU' }); $selected = if ($dfu.Count -gt 0) { $dfu[0] } else { $lego[0] }; if ($lego.Count -gt 1) { [Console]::Error.WriteLine('複数のLEGOデバイスが見つかりました。DFU優先で先頭を使用します。'); foreach ($d in $lego) { [Console]::Error.WriteLine('  ' + $d.BusId + ' ' + $d.Description) }; [Console]::Error.WriteLine('selected: ' + $selected.BusId) }; [Console]::WriteLine($selected.BusId)"`) do if not "%%I"=="" if not defined USB_BUSID set "USB_BUSID=%%I"

echo %USB_BUSID% | findstr /R "^[0-9][0-9]*-[0-9][0-9]*$" >nul
if errorlevel 1 set "USB_BUSID="

if not defined USB_BUSID (
    >&2 echo BUSID自動検出に失敗しました。LEGOデバイスを接続しDFUモードを確認してください。
    popd >nul
    set "EXIT_CODE=3"
    goto :finalize
)

echo Using USB_BUSID=%USB_BUSID%

echo usbipd bind --busid %USB_BUSID%
"%POWERSHELL_BIN%" -NoProfile -NonInteractive -Command "usbipd bind --busid '%USB_BUSID%'" >nul 2>&1
if errorlevel 1 (
    >&2 echo bindに失敗しました（既にbind済み、または管理者権限不足の可能性）。attachを続行します。
)

echo usbipd attach --wsl --busid %USB_BUSID% --auto-attach
"%POWERSHELL_BIN%" -NoProfile -NonInteractive -Command "usbipd attach --wsl --busid '%USB_BUSID%' --auto-attach" >nul 2>&1
if errorlevel 1 (
    >&2 echo auto-attach付きattachに失敗しました。usbipdのバージョン未対応の可能性があるため通常attachにフォールバックします。
    "%POWERSHELL_BIN%" -NoProfile -NonInteractive -Command "usbipd attach --wsl --busid '%USB_BUSID%'" >nul 2>&1
    if errorlevel 1 (
        >&2 echo attachに失敗しました。管理者権限やusbipdの状態を確認してください。
        popd >nul
        set "EXIT_CODE=4"
        goto :finalize
    )
)

echo attach結果を確認中...
"%POWERSHELL_BIN%" -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $busId='%USB_BUSID%'; $deadline=(Get-Date).AddSeconds(12); while ((Get-Date) -lt $deadline) { $state = usbipd state ^| ConvertFrom-Json; $dev = @($state.Devices ^| Where-Object { $_.BusId -eq $busId }) ^| Select-Object -First 1; $attached = $false; if ($null -ne $dev) { if ($dev.PSObject.Properties.Name -contains 'ClientIPAddress') { $attached = -not [string]::IsNullOrWhiteSpace([string]$dev.ClientIPAddress) } elseif ($dev.PSObject.Properties.Name -contains 'IsAttached') { $attached = [bool]$dev.IsAttached } elseif ($dev.PSObject.Properties.Name -contains 'Attached') { $attached = [bool]$dev.Attached } }; $usbReady = $false; try { $probe = wsl.exe -e sh -lc 'if [ -d /dev/bus/usb ] && find /dev/bus/usb -mindepth 2 -maxdepth 2 -type c | grep -q .; then echo READY; fi' 2>$null; if ($probe -match 'READY') { $usbReady = $true } } catch { $usbReady = $false }; if ($attached -and $usbReady) { [Console]::WriteLine('OK'); exit 0 }; Start-Sleep -Milliseconds 500 }; [Console]::Error.WriteLine('WSL2へのUSB反映を確認できませんでした。DFUモード、usbipd attach状態、WSL起動状態を確認してください。'); exit 4" >nul 2>&1
if errorlevel 1 (
    >&2 echo USB attach の検証に失敗しました。
    popd >nul
    set "EXIT_CODE=4"
    goto :finalize
)

echo USB attach が完了しました。
popd >nul
set "EXIT_CODE=0"

:finalize
if /I "%WAIT_ON_EXIT%"=="1" (
    echo.
    echo 終了するには何かキーを押してください...
    pause >nul
)
exit /b %EXIT_CODE%
