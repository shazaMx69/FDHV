# Refreshes PATH so npm works in terminals opened before Node.js was installed.
$nodeDir = "C:\Program Files\nodejs"
if (Test-Path $nodeDir) {
  $env:Path = "$nodeDir;" + $env:Path
}
Set-Location $PSScriptRoot
& npm.cmd run dev
