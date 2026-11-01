[CmdletBinding(PositionalBinding=$false)]
param(
  [string]$BootstrapDart,
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$FvmArguments
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$oldPub=$env:PUB_CACHE
$oldFvm=$env:FVM_CACHE_PATH
try {
  $env:PUB_CACHE=Join-Path $root '.tooling/pub-cache'
  $env:FVM_CACHE_PATH=Join-Path $root '.tooling/fvm'
  $pinnedDart=Join-Path $root '.fvm/flutter_sdk/bin/cache/dart-sdk/bin/dart.exe'
  if(Test-Path $pinnedDart){$runnerDart=$pinnedDart}
  elseif($BootstrapDart){$runnerDart=$BootstrapDart}
  else {$runnerDart=(Get-Command dart -ErrorAction Stop).Source}
  if(-not(Test-Path (Join-Path $env:PUB_CACHE 'global_packages/fvm/.dart_tool/package_config.json'))){
    & $runnerDart pub global activate fvm 4.3.2
    if($LASTEXITCODE -ne 0){throw '프로젝트 FVM 설치 실패'}
  }
  Push-Location $root
  try {
    & $runnerDart pub global run fvm:main @FvmArguments
    if($LASTEXITCODE -ne 0){throw "FVM 명령 실패: $FvmArguments"}
  } finally {Pop-Location}
} finally {
  $env:PUB_CACHE=$oldPub
  $env:FVM_CACHE_PATH=$oldFvm
}
