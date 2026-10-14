$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $toolsDir 'helpers.ps1')

$maintenanceTool = Get-WhatPulseMaintenanceTool
if (-not $maintenanceTool) {
  Write-Warning "$env:ChocolateyPackageName has already been uninstalled by other means."
  return
}

Uninstall-WhatPulse $maintenanceTool
