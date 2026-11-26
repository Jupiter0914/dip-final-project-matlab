param([Parameter(Mandatory=$true)][ValidateSet('dev1','dev2','confirm')][string]$Stage)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logs=Join-Path $root 'local/perf/logs'
[void][IO.Directory]::CreateDirectory($logs)
foreach($sid in 1..3) {
    $env:DIP_PERF_LAUNCH_MS=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    matlab -singleCompThread -sd $root -logfile (Join-Path $logs "$Stage-S$sid.log") -batch "addpath('performance/runner');efSession(pwd,'$Stage',$sid)"
    if($LASTEXITCODE -ne 0){throw "$Stage S$sid failed"}
}
