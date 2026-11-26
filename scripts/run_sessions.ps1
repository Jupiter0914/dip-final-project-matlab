$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSScriptRoot
$logDir=Join-Path $root 'local/logs'
[void][IO.Directory]::CreateDirectory($logDir)
foreach ($id in 1..3) {
    $env:DIP_LAUNCH_UNIX_MS=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    matlab -singleCompThread -sd $root -logfile (Join-Path $logDir "session-$id.log") -batch "dip('confirm',$id)"
    if ($LASTEXITCODE -ne 0) {throw "Session $id failed"}
}

