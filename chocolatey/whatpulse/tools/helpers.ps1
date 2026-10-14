# Shared by chocolateyinstall.ps1 and chocolateyuninstall.ps1.

# Path to the installed WhatPulseMaintenanceTool.exe, or $null when WhatPulse
# isn't installed.
function Get-WhatPulseMaintenanceTool {
  [array]$keys = Get-UninstallRegistryKey -SoftwareName 'WhatPulse*'

  if ($keys.Count -gt 1) {
    $names = ($keys | ForEach-Object { $_.DisplayName }) -join ', '
    throw "$($keys.Count) matches found for 'WhatPulse*' ($names). Refusing to guess; uninstall manually."
  }

  # The installer registers WhatPulseMaintenanceTool.exe as the UninstallString.
  if ($keys.Count -eq 1) {
    $maintenanceTool = $keys[0].UninstallString.Trim('"')
    if (Test-Path $maintenanceTool) {
      return $maintenanceTool
    }
  }

  # Fall back to the default install location.
  $maintenanceTool = Join-Path $env:ProgramFiles 'WhatPulse\WhatPulseMaintenanceTool.exe'
  if (Test-Path $maintenanceTool) {
    return $maintenanceTool
  }

  return $null
}

# Stops a process and everything it started, deepest first. Deliberately a loop
# rather than a function that calls itself: recursion stalls Chocolatey's
# package validator.
function Stop-ProcessTree([int]$ProcessId) {
  $all  = @(Get-CimInstance Win32_Process)
  $tree = @($ProcessId)
  for ($i = 0; $i -lt $tree.Count; $i++) {
    $parent = $tree[$i]
    $tree += @($all |
      Where-Object { $_.ParentProcessId -eq $parent -and $tree -notcontains [int]$_.ProcessId } |
      ForEach-Object { [int]$_.ProcessId })
  }
  [array]::Reverse($tree)
  $tree | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
}

function Get-ExitClientProcess {
  Get-CimInstance Win32_Process -Filter "Name = 'WhatPulse.exe'" |
    Where-Object { $_.CommandLine -match '--exit_client' }
}

# Runs `WhatPulseMaintenanceTool.exe purge`, which removes all components and
# the program directory. The maintenance tool's control script shuts down a
# running WhatPulse.exe first.
function Uninstall-WhatPulse([string]$MaintenanceTool) {
  # Workaround for WhatPulse <= 6.3.1; harmless on fixed versions.
  # The control script shuts the client down with `WhatPulse.exe --exit_client`.
  # With no client running, that starts one instead and never returns, so the
  # purge waits on it forever. Stop that process so the purge can carry on.
  # When a client is running, --exit_client is doing its job: give it time.
  $clientWasRunning = [bool](Get-Process -Name 'WhatPulse' -ErrorAction SilentlyContinue)
  $exitClientGrace  = if ($clientWasRunning) { 30 } else { 3 }
  $purgeTimeout     = 600

  # --accept-messages answers any message box that would block a headless run.
  $proc = Start-Process -FilePath $MaintenanceTool -ArgumentList '--accept-messages --confirm-command purge' -PassThru
  $null = $proc.Handle
  $started = Get-Date

  while (-not $proc.WaitForExit(1000)) {
    $cutoff = (Get-Date).AddSeconds(-$exitClientGrace)
    Get-ExitClientProcess | Where-Object { $_.CreationDate -lt $cutoff } | ForEach-Object {
      Write-Verbose "Stopping stuck 'WhatPulse.exe --exit_client' (PID $($_.ProcessId))."
      Stop-ProcessTree $_.ProcessId
    }

    if (((Get-Date) - $started).TotalSeconds -gt $purgeTimeout) {
      Stop-ProcessTree $proc.Id
      throw "WhatPulseMaintenanceTool.exe purge did not finish within $purgeTimeout seconds."
    }
  }

  if ($proc.ExitCode -ne 0) {
    throw "WhatPulseMaintenanceTool.exe purge failed with exit code $($proc.ExitCode)."
  }
}
