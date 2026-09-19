$ErrorActionPreference = 'Stop'

$packageName = $env:ChocolateyPackageName
[array]$keys = Get-UninstallRegistryKey -SoftwareName 'WhatPulse*'

if ($keys.Count -eq 0) {
  Write-Warning "$packageName has already been uninstalled by other means."
  return
}

if ($keys.Count -gt 1) {
  Write-Warning "$($keys.Count) matches found for 'WhatPulse*'. Refusing to guess; uninstall manually."
  $keys | ForEach-Object { Write-Warning "- $($_.DisplayName)" }
  return
}

# The installer registers WhatPulseMaintenanceTool.exe as the UninstallString.
$maintenanceTool = $keys[0].UninstallString.Trim('"')
if (-not (Test-Path $maintenanceTool)) {
  # Fall back to the default install location.
  $maintenanceTool = Join-Path $env:ProgramFiles 'WhatPulse\WhatPulseMaintenanceTool.exe'
}

if (-not (Test-Path $maintenanceTool)) {
  Write-Warning "Maintenance tool not found; WhatPulse may already be removed."
  return
}

# `purge` removes all components and the program directory. The maintenance
# tool's control script shuts down a running WhatPulse.exe first.
$uninstallArgs = @{
  packageName    = $packageName
  fileType       = 'exe'
  file           = $maintenanceTool
  silentArgs     = '--confirm-command purge'
  validExitCodes = @(0)
}

Uninstall-ChocolateyPackage @uninstallArgs
