#!/usr/bin/env pwsh

# @raycast.schemaVersion 1
# @raycast.title Work Mode
# @raycast.mode silent
# @raycast.packageName Profile
# @raycast.icon 💼

& (Join-Path $HOME '.config\profile\profile-toggle.ps1') -Work
Write-Output 'Work profile on'
