$ErrorActionPreference = "Stop"

try {
    $state = usbipd state | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("Failed to read usbipd state. Check usbipd installation and permissions.")
    exit 3
}

$devices = @($state.Devices | Sort-Object BusId)
$candidates = @(
    $devices |
    Where-Object {
        $desc = [string]($_.Description)
        $instanceId = ""
        if ($_.PSObject.Properties.Name -contains "InstanceId") {
            $instanceId = [string]($_.InstanceId)
        }

        ($desc -match "(?i)LEGO") -or
        ($desc -match "(?i)DFU") -or
        ($desc -match "(?i)SPIKE") -or
        ($desc -match "(?i)MINDSTORMS") -or
        ($instanceId -match "(?i)VID_0694")
    }
)

if ($candidates.Count -eq 0) {
    [Console]::Error.WriteLine("No LEGO candidate device found. Check usbipd state output.")
    foreach ($d in $devices) {
        [Console]::Error.WriteLine("  " + [string]($d.BusId) + " " + [string]($d.Description))
    }
    exit 3
}

$dfu = @($candidates | Where-Object { [string]($_.Description) -match "(?i)DFU" })
$selected = if ($dfu.Count -gt 0) { $dfu[0] } else { $candidates[0] }
$busId = [string]($selected.BusId)

if ([string]::IsNullOrWhiteSpace($busId) -or ($busId -notmatch "^[0-9]+-[0-9]+(\.[0-9]+)*$")) {
    [Console]::Error.WriteLine("Unexpected BUSID format: " + $busId)
    exit 3
}

if ($candidates.Count -gt 1) {
    [Console]::Error.WriteLine("Multiple candidate devices were found. DFU candidate is preferred.")
    foreach ($d in $candidates) {
        [Console]::Error.WriteLine("  " + [string]($d.BusId) + " " + [string]($d.Description))
    }
    [Console]::Error.WriteLine("selected: " + $busId)
}

[Console]::WriteLine($busId)
exit 0
