# Refreshes PATH so flutter works in terminals opened before Flutter was installed.
$flutterBin = "C:\Users\USER\flutter\bin"
if (Test-Path $flutterBin) {
  $env:Path = "$flutterBin;" + $env:Path
}
$nodeDir = "C:\Program Files\nodejs"
if (Test-Path $nodeDir) {
  $env:Path = "$nodeDir;" + $env:Path
}
Set-Location $PSScriptRoot
flutter run -d chrome --web-port=8080
