$ErrorActionPreference = 'Stop'
Write-Output "Windows profile: $env:USERPROFILE"
Write-Output "Local app data: $env:LOCALAPPDATA"
Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free
& wsl.exe --version
& wsl.exe --help | Select-String -Pattern '--name','--location','--no-launch','--from-file','--web-download' -Context 0,1
