# ---------------------------
#     xvi.ps1  by nooriro
# ---------------------------
# * Extracts only vendor image from Google's driver binaries tgz [1]
#   [1] https://developers.google.com/android/drivers
# * The vendor image will be renamed to 'vendor-userdebug.img'
# * Requires Windows 10 Build 17063 or higher to run tar
# ------------------------------------------------------------------------------
# Usage: (1) Download a 'vendor image' tgz into working directory
#        (2) Place this script in the same directory
#        (3) Run the command below in Command Prompt :
#            powershell -ex bypass -f xvi.ps1
# ------------------------------------------------------------------------------


if ( $PSEdition -ne "Core" -or $IsWindows ) {
  if ( [Environment]::OSVersion.Version.Build -lt 17063 ) {
    "! This script requires Windows 10 Build 17063 or higher"
    exit 1
  }
}

Set-Variable -Option Constant  -Name PAYLOAD_START_LINE  -Value 315
Set-Variable -Option Constant  -Name LF                  -Value ([Byte]10)
Set-Variable -Option Constant `
             -Name TGZ_FILENAME_REGEX `
             -Value "google_devices-([a-z]+)-([a-z0-9\.]+)-([0-9a-f]{8})\.tgz"

$tgz = Get-ChildItem *.tgz -File | 
  Where-Object { $_.Name -match $TGZ_FILENAME_REGEX } |
  Sort-Object LastWriteTime |
  Select-Object -Last 1

if ( ! $tgz ) {
  "! No vendor image tgz file in current directory"
  "  Download a 'vendor image' tgz on https://developers.google.com/android/drivers"
  "  and place it in the current directory, and run this script again."
  exit 2
}

$tgzName      = $tgz.Name
$tgzDevice    = $tgz.Name -replace $TGZ_FILENAME_REGEX, '$1'
$tgzBuildNum  = $tgz.Name -replace $TGZ_FILENAME_REGEX, '$2'
$tgzHash      = $tgz.Name -replace $TGZ_FILENAME_REGEX, '$3'
"* Vendor image tgz:            [${tgzName}]"
"* Device:                      [${tgzDevice}]"
"* Build Number:                [$($tgzBuildNum.ToUpper())]"

if ( Test-Path "vendor-userdebug.img" ) {
  "! 'vendor-userdebug.img' exists in current directory"
  "  Remove, rename, or move that file and run this script again."
  exit 3
}

"- Extracing file(s) from vendor image tgz"
$dir = New-Guid
$null = New-Item $dir -Type Directory
tar xvzf "$tgzName" -C "$dir" 2> $null

"- Skipping first $($PAYLOAD_START_LINE - 1) lines of  [extract-google_devices-${tgzDevice}.sh]"
Set-Location $dir
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
$bytes = [IO.File]::ReadAllBytes( "extract-google_devices-${tgzDevice}.sh" )
$p = 0
for ( $i = 1; $i -lt $PAYLOAD_START_LINE; $i++ ) {
  $p = [Array]::IndexOf( $bytes, $LF, $p ) + 1
}

"- Saving payload data as       [payload.tgz]"
$fs = [IO.File]::Create( "payload.tgz" )
$fs.Write( $bytes, $p, $bytes.Length - $p )
$fs.Close()

"- Extracing file(s) from payload data tgz"
tar xvzf payload.tgz 2> $null

"- Moving vendor.img to         [vendor-userdebug.img] in current directory"
Move-Item "vendor/google_devices/${tgzDevice}/proprietary/vendor.img" ../vendor-userdebug.img

"- Cleaning up all intermediate files/folders"
Set-Location ..
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
Remove-Item $dir -Recurse -Force
#Remove-Item "$tgzName"

Get-Item vendor-userdebug.img
exit 0