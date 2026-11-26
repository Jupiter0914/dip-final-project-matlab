param([ValidateSet('replay','fresh')][string]$Mode='replay',[string]$Destination)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Invoke-StudyMatlab([string]$place,[string]$code){
    matlab -singleCompThread -sd $place -batch $code
    if($LASTEXITCODE -ne 0){throw 'MATLAB process failed; its existing observations are retained'}
}
if($Mode -eq 'replay'){
    if(!(Test-Path -LiteralPath (Join-Path $root 'local/perf/blobs'))){throw '先使用优化审核包恢复实际接收的 PM31'}
    Invoke-StudyMatlab $root "addpath('performance/runner');efReplay(pwd);"
    return
}
if(!$Destination){$Destination=Join-Path ([IO.Path]::GetTempPath()) ('dip-exact-fresh-'+(Get-Date -Format yyyyMMdd-HHmmss))}
if(Test-Path -LiteralPath $Destination){throw '请为 fresh 指定尚不存在的目录，避免覆盖一次测量'}
[void][IO.Directory]::CreateDirectory($Destination)
$copy=@('AGENTS.md','dip.m','src','tests','scripts','configs','performance','docs','data/manifests','data/compat')
foreach($relative in $copy){
    $out=Join-Path $Destination $relative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($out))
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $out -Recurse
}
foreach($relative in @('data/dev','data/poly04','data/exact_fast','local/perf/official')){
    $inPath=Join-Path $root $relative
    if(Test-Path -LiteralPath $inPath){
        $out=Join-Path $Destination $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($out))
        Copy-Item -LiteralPath $inPath -Destination $out -Recurse
    }
}
if(!(Test-Path -LiteralPath (Join-Path $Destination 'data/dev')) -or !(Test-Path -LiteralPath (Join-Path $Destination 'data/poly04'))){
    & (Join-Path $Destination 'scripts/restore_data.ps1')
}
$selected=Get-Content -LiteralPath (Join-Path $root 'performance/selected_kernel.json') -Raw | ConvertFrom-Json
Invoke-StudyMatlab $Destination "dip('test');addpath('performance/profile');profileDevelopment('reference','reference');"
$stages=@('dev1');if($selected.version -eq 'dev2'){$stages+='dev2'}
foreach($stage in $stages){
    Invoke-StudyMatlab $Destination "addpath('performance/runner');efSetup(pwd,'$stage');runEquivalence('dev','$stage');efDevGuard(pwd,'$stage','record');"
    & (Join-Path $Destination 'performance/runner/run_sessions.ps1') -Stage $stage
    Invoke-StudyMatlab $Destination "addpath('performance/runner');efSetup(pwd,'$stage');efCollect(pwd,'$stage');efGate(pwd,'$stage');"
    if($stage -eq 'dev1'){
        Invoke-StudyMatlab $Destination "addpath('performance/runner');efSetup(pwd,'dev1');profileDevelopment('fast','dev1');perfAnalysis(pwd,'development');"
    }
    $gate=Get-Content -LiteralPath (Join-Path $Destination "perf_results/$stage/decision.json") -Raw | ConvertFrom-Json
    if($stage -eq 'dev1' -and $gate.go -and $selected.version -eq 'dev2'){
        throw "本机轮1已过门，与归档路径不同。停止于新开发结果 $Destination"
    }
}
Invoke-StudyMatlab $Destination "addpath('performance/runner');efSetup(pwd,'current');runEquivalence('old300','old300');profileDevelopment('fast','selected');"
if($selected.decision -eq 'GO' -and $gate.go){
    if(!(Test-Path -LiteralPath (Join-Path $Destination 'data/exact_fast'))){
        Invoke-StudyMatlab $Destination "addpath('performance/sampling');restorePerfInputs(pwd);"
    }
    & (Join-Path $Destination 'performance/runner/run_sessions.ps1') -Stage confirm
    Invoke-StudyMatlab $Destination "addpath('performance/runner');efSetup(pwd,'current');efCollect(pwd,'timed');efCollect(pwd,'fixed');perfAnalysis(pwd,'formal');"
}else{
    Invoke-StudyMatlab $Destination "addpath('performance/analysis');perfAnalysis(pwd,'development');"
}
Write-Output "独立重测输出 $Destination"
