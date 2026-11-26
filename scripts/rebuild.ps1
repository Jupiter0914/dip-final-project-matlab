param([ValidateSet('fresh','replay')][string]$Mode='fresh')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if ($Mode -eq 'fresh') {
    if (Test-Path -LiteralPath (Join-Path $root 'results/sessions/S1')) {throw '该目录包含原始计时，选择新的检出目录进行独立复测'}
    & (Join-Path $PSScriptRoot 'restore_data.ps1')
    matlab -singleCompThread -sd $root -batch "dip('test');dip('smoke');"
    if ($LASTEXITCODE -ne 0) {throw 'Preflight failed'}
    & (Join-Path $PSScriptRoot 'run_sessions.ps1')
}
matlab -singleCompThread -sd $root -batch "addpath('scripts');audit_all(pwd)"
if ($LASTEXITCODE -ne 0) {throw 'Offline audit failed'}
if ($Mode -eq 'replay') {
    matlab -singleCompThread -sd $root -batch "addpath('scripts');run_exploration('verify')"
    if ($LASTEXITCODE -ne 0) {throw 'Development replay failed'}
}
if ($Mode -eq 'fresh') {
    matlab -singleCompThread -sd $root -batch "addpath('scripts');run_exploration('all')"
    if ($LASTEXITCODE -ne 0) {throw 'Development analysis failed'}
}
