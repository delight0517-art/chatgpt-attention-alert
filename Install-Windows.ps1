$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'ChatGPTAttentionAlert'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'plugin\companion\windows\alert.ps1') (Join-Path $destination 'alert.ps1')
Write-Output "Installed ChatGPT Attention Alert to $destination"
