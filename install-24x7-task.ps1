$taskName = "MinecraftServer24x7"
$scriptPath = Join-Path $PSScriptRoot "start.bat"
$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable

try {
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
  Write-Host "Task created: $taskName (ONLOGON)"
} catch {
  Write-Error "Failed to create task $taskName. Run this script from an elevated PowerShell window."
  exit 1
}
