# ---------------------------
#     xvi.ps1  by nooriro
# ---------------------------
# * Extracts only vendor image from Google's driver binaries tgz [1]
#   [1] https://developers.google.com/android/drivers
# * The vendor image will be renamed to 'vendor-userdebug.img'
# ------------------------------------------------------------------------------
# Usage: (1) Download a 'vendor image' tgz into working directory
#        (2) Place this script in the same directory
#        (3) Run the command below in Command Prompt :
#            powershell -ex bypass -f xvi.ps1
# ------------------------------------------------------------------------------


$nativeTar = $true
if ( $PSEdition -ne "Core" -or $IsWindows ) {
  if ( [Environment]::OSVersion.Version.Build -lt 17063 ) {
    $nativeTar = $false
  }
}

Set-Variable -Option Constant  -Name PAYLOAD_START_LINE  -Value 315
Set-Variable -Option Constant  -Name LF                  -Value ([byte]10)
Set-Variable -Option Constant  -Name BUFFER_SIZE         -Value 65536
Set-Variable -Option Constant `
             -Name TGZ_FILENAME_REGEX `
             -Value "google_devices-([a-z]+)-([a-z0-9\.]+)-([0-9a-f]{8})\.tgz"
if ( -Not $nativeTar ) {
  Set-Variable -Option Constant `
               -Name SEVENZIPA_URL `
               -Value "https://github.com/nooriro/xvi/raw/0360be2fe052630156e28495650d383d68c0c6d8/7za.exe"
  Set-Variable -Option Constant  -Name SEVENZIPA_FILENAME  -Value "7za.exe"
}

$tgz = Get-ChildItem *.tgz -File | 
  Where-Object { $_.Name -match $TGZ_FILENAME_REGEX } |
  Sort-Object LastWriteTime |
  Select-Object -Last 1

if ( ! $tgz ) {
  "! No vendor image tgz file in current directory"
  "  Download a 'vendor image' tgz on https://developers.google.com/android/drivers"
  "  and place it in the current directory, and run this script again."
  exit 1
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
  exit 2
}

"- Extracing file(s) from vendor image tgz"
$dir = New-Guid
$null = New-Item $dir -Type Directory
if ( $nativeTar ) {
  tar xvzf "$tgzName" -C "$dir" 2> $null
} else {
  try {
    # "3 ways to download files with PowerShell"
    # https://blog.jourdant.me/post/3-ways-to-download-files-with-powershell
    $wc = [Net.WebClient]::new()
    $wc.DownloadFile( $SEVENZIPA_URL, "${pwd}\${dir}\${SEVENZIPA_FILENAME}" )
  } catch {
    "! An error occured while downloading ${SEVENZIPA_FILENAME}"
    $_
    Remove-Item $dir -Recurse -Force
    exit 3
  }
  # "Programmatically extract tar.gz in a single step (on Windows with 7-Zip)"
  # https://stackoverflow.com/a/14699663
  & cmd "/c ${dir}\7za x ""${tgzName}"" -so | ${dir}\7za x -aoa -si -ttar -o""${dir}"" > NUL"
}
#$memUsage = [GC]::GetTotalMemory($false)
#"    Memory Usage               [{0}] = [{1:F1} MiB]" -f $memUsage, ($memUsage / 1048576)

"- Skipping first $($PAYLOAD_START_LINE - 1) lines of  [extract-google_devices-${tgzDevice}.sh]"
Set-Location $dir
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
#$stopWatch1 = [Diagnostics.Stopwatch]::new()
#$stopWatch1.Start()
$fs1 = [IO.FileStream]::new("extract-google_devices-${tgzDevice}.sh", [IO.FileMode]::Open, [IO.FileAccess]::Read)
$buf = [byte[]]::new($BUFFER_SIZE)
#$start = 0L
$cnt = 0
:outer while ( ( $len = $fs1.Read($buf, 0, $BUFFER_SIZE) ) -gt 0 ) {
  for ($i = 0; $i -lt $len; $i++) {
    if ($buf[$i] -eq $LF) {
      $cnt++
      if ($cnt -eq $PAYLOAD_START_LINE - 1) {
        break outer
      }
    }
  }
  #$start += $len
} # breaks to here
#"D   start: [0x{0:X016}]   len: [0x{1:X08}]   i: [0x{2:X08}]   cnt: [{3}]" -f $start, $len, $i, $cnt
#$stopWatch1.Stop()
#"    Execution Time             [{0:F7}]" -f $stopWatch1.Elapsed.TotalSeconds
#$memUsage = [GC]::GetTotalMemory($false)
#"    Memory Usage               [{0}] = [{1:F1} MiB]" -f $memUsage, ($memUsage / 1048576)
if ($cnt -lt $PAYLOAD_START_LINE - 1) {
  "! Payload data is not exist in 'extract-google_devices-${tgzDevice}.sh'"
  $fs1.Close()
  Set-Location ..
  [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
  Remove-Item $dir -Recurse -Force
  exit 4
}

"- Saving payload data as       [payload.tgz]"
#$stopWatch2 = [Diagnostics.Stopwatch]::new()
#$stopWatch2.Start()
$fs2 = [IO.FileStream]::new("payload.tgz", [IO.FileMode]::Create, [IO.FileAccess]::Write)
$i++
if ($i -lt $len) {
  #"D  start+i:[0x{0:X016}]  len-i:[0x{1:X08}]" -f ($start + $i), ($len - $i)
  $fs2.Write($buf, $i, $len - $i)
}
#$start += $len
while ( ( $len = $fs1.Read($buf, 0, $BUFFER_SIZE) ) -gt 0 ) {
  #"D   start: [0x{0:X016}]   len: [0x{1:X08}]" -f $start, $len
  $fs2.Write($buf, 0, $len)
  #$start += $len
}
$fs2.Close()
$fs1.Close()
#$stopWatch2.Stop()
#"    Execution Time             [{0:F7}]" -f $stopWatch2.Elapsed.TotalSeconds
#"    Total Execution Time       [{0:F7}]" -f ($stopWatch1.Elapsed + $stopWatch2.Elapsed).TotalSeconds
#$memUsage = [GC]::GetTotalMemory($false)
#"    Memory Usage               [{0}] = [{1:F1} MiB]" -f $memUsage, ($memUsage / 1048576)
#$memUsage = [GC]::GetTotalMemory($true)
#"    Memory Usage (After GC)    [{0}] = [{1:F1} MiB]" -f $memUsage, ($memUsage / 1048576)

"- Extracing file(s) from payload data tgz"
if ( $nativeTar ) {
  tar xvzf payload.tgz 2> $null
} else {
  & cmd "/c 7za x payload.tgz -so | 7za x -aoa -si -ttar > NUL"
}

"- Moving vendor.img to         [vendor-userdebug.img] in current directory"
Move-Item "vendor/google_devices/${tgzDevice}/proprietary/vendor.img" ../vendor-userdebug.img

"- Cleaning up all intermediate files/folders"
Set-Location ..
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
Remove-Item $dir -Recurse -Force
#Remove-Item "$tgzName"

Get-Item vendor-userdebug.img
exit 0
