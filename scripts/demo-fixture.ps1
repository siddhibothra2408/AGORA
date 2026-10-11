# Agora Demo Fixture Mode Startup Script (Windows PowerShell)
# Starts emulators in offline fixture mode (AI_PROVIDER=fixture)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptPath\demo-up.ps1" -FixtureMode
