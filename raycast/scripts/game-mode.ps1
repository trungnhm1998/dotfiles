#!/usr/bin/env pwsh

# @raycast.schemaVersion 1
# @raycast.title Game Mode
# @raycast.mode silent
# @raycast.packageName Profile
# @raycast.icon 🎮

& (Join-Path $HOME '.config\profile\profile-toggle.ps1') -Gaming
Write-Output 'Gaming profile on'
