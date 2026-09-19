$ErrorActionPreference = 'Stop'

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
