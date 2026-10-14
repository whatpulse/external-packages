$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $toolsDir 'helpers.ps1')

# The WhatPulse installer refuses to install over an existing installation, and
# `choco upgrade` never runs the old package's uninstall script. Remove the
# installed version first.
$maintenanceTool = Get-WhatPulseMaintenanceTool
if ($maintenanceTool) {
  Write-Host 'Removing the installed WhatPulse before installing this version.'
  Uninstall-WhatPulse $maintenanceTool
}

# {{VERSION}} and {{CHECKSUM}} are replaced by the chocolatey workflow before `choco pack`.
$version  = '{{VERSION}}'
$url64    = "https://releases.whatpulse.org/archives/$version/windows/whatpulse-win-$version.exe"

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  fileType       = 'exe'
  url64bit       = $url64
  checksum64     = '{{CHECKSUM}}'
  checksumType64 = 'sha256'
  softwareName   = 'WhatPulse*'
  # Qt Installer Framework CLI. Same switches as the winget manifest and the
  # documented unattended install, plus InstallForAllUsers because Chocolatey
  # installs machine-wide. NoLaunch keeps the app from starting mid-install.
  silentArgs     = '--accept-messages --accept-licenses --confirm-command install InstallForAllUsers=true NoLaunch=true'
  validExitCodes = @(0)
}

Install-ChocolateyPackage @packageArgs
