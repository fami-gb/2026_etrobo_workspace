#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

POWERSHELL_BIN="powershell.exe"

if ! command -v "${POWERSHELL_BIN}" >/dev/null 2>&1; then
	echo "PowerShell が見つかりません: ${POWERSHELL_BIN}" >&2
	exit 2
fi

cd "${REPO_ROOT}"

echo "LEGO 名を含むUSBデバイスを自動検出します..."
detect_cmd="$(cat <<'PS'
$ErrorActionPreference = "Stop"
$state = usbipd state | ConvertFrom-Json
$lego = @(
  $state.Devices |
  Where-Object { $_.Description -match "LEGO" } |
  Sort-Object BusId
)
if ($lego.Count -eq 0) {
  Write-Error "Description に LEGO を含むUSBデバイスが見つかりませんでした。"
	exit 3
}
$dfu = @($lego | Where-Object { $_.Description -match "DFU" })
$selected = if ($dfu.Count -gt 0) { $dfu[0] } else { $lego[0] }
if ($lego.Count -gt 1) {
  [Console]::Error.WriteLine("複数のLEGOデバイスが見つかりました。DFU優先で先頭を使用します。")
  foreach ($d in $lego) {
    [Console]::Error.WriteLine("  " + $d.BusId + " " + $d.Description)
  }
  [Console]::Error.WriteLine("selected: " + $selected.BusId)
}
[Console]::WriteLine($selected.BusId)
PS
)"
if ! USB_BUSID="$("${POWERSHELL_BIN}" -NoProfile -NonInteractive -Command "${detect_cmd}")"; then
	echo "BUSID自動検出に失敗しました。LEGOデバイスを接続しDFUモードを確認してください。" >&2
	exit 3
fi

echo "Using USB_BUSID=${USB_BUSID}"

echo "usbipd bind --busid ${USB_BUSID}"
if ! "${POWERSHELL_BIN}" -NoProfile -NonInteractive -Command "usbipd bind --busid '${USB_BUSID}'" >/dev/null; then
	echo "bindに失敗しました（既にbind済み、または管理者権限不足の可能性）。attachを続行します。" >&2
fi

echo "usbipd attach --wsl --busid ${USB_BUSID} --auto-attach"
if ! "${POWERSHELL_BIN}" -NoProfile -NonInteractive -Command "usbipd attach --wsl --busid '${USB_BUSID}' --auto-attach" >/dev/null; then
  echo "auto-attach付きattachに失敗しました。usbipdのバージョン未対応の可能性があるため通常attachにフォールバックします。" >&2
  if ! "${POWERSHELL_BIN}" -NoProfile -NonInteractive -Command "usbipd attach --wsl --busid '${USB_BUSID}'" >/dev/null; then
    echo "attachに失敗しました。管理者権限やusbipdの状態を確認してください。" >&2
    exit 4
  fi
fi

echo "attach結果を確認中..."
verify_cmd="$(cat <<PS
\$ErrorActionPreference = "Stop"
\$busId = "${USB_BUSID}"
\$deadline = (Get-Date).AddSeconds(12)

while ((Get-Date) -lt \$deadline) {
  \$state = usbipd state | ConvertFrom-Json
  \$dev = @(\$state.Devices | Where-Object { \$_.BusId -eq \$busId }) | Select-Object -First 1
  \$attached = \$false
  if (\$null -ne \$dev) {
    if (\$dev.PSObject.Properties.Name -contains "ClientIPAddress") {
      \$attached = -not [string]::IsNullOrWhiteSpace([string]\$dev.ClientIPAddress)
    } elseif (\$dev.PSObject.Properties.Name -contains "IsAttached") {
      \$attached = [bool]\$dev.IsAttached
    } elseif (\$dev.PSObject.Properties.Name -contains "Attached") {
      \$attached = [bool]\$dev.Attached
    }
  }

  \$usbReady = \$false
  try {
    \$probe = wsl.exe -e sh -lc "if [ -d /dev/bus/usb ] && find /dev/bus/usb -mindepth 2 -maxdepth 2 -type c | grep -q .; then echo READY; fi" 2>\$null
    if (\$probe -match "READY") {
      \$usbReady = \$true
    }
  } catch {
    \$usbReady = \$false
  }

  if (\$attached -and \$usbReady) {
    [Console]::WriteLine("OK")
    exit 0
  }

  Start-Sleep -Milliseconds 500
}

[Console]::Error.WriteLine("WSL2へのUSB反映を確認できませんでした。DFUモード、usbipd attach状態、WSL起動状態を確認してください。")
exit 4
PS
)"
if ! "${POWERSHELL_BIN}" -NoProfile -NonInteractive -Command "${verify_cmd}" >/dev/null; then
	echo "USB attach の検証に失敗しました。" >&2
	exit 4
fi

echo "USB attach が完了しました。続けて make upload を実行します。"
