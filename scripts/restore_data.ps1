param([switch]$DevelopmentOnly, [string]$OxfordArchive, [string]$LemsArchive)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dataRoot = (Get-Item -LiteralPath (Join-Path $root 'data')).FullName
$rows = @(Import-Csv -LiteralPath (Join-Path $root 'data/manifests/dev.csv'))
if ($rows.Count -ne 36 -or @($rows | Where-Object { $_.official -ne 'trainval' }).Count) { throw 'Invalid development roster' }
if (!$DevelopmentOnly) { $rows += Import-Csv -LiteralPath (Join-Path $root 'data/manifests/frozen.csv') }
$sets = @(
    @{Dataset='Oxford'; Archive=$OxfordArchive; Cache='local/perf/official/annotations.tar.gz'; Sha='52425fb6de5c424942b7626b428656fcbd798db970a937df61750c0f1d358e91'; Url='https://thor.robots.ox.ac.uk/datasets/pets/annotations.tar.gz'},
    @{Dataset='LEMS'; Archive=$LemsArchive; Cache='local/assets/Datasets_LEMS_MPEG7.rar'; Sha='f6a132c16ca4800fc9cfbe3d469a086599aba67783448362c0bc2275bf7e6d1c'; Url='https://drive.usercontent.google.com/download?id=1_A3u9nnwx--FMbmn8HAjBdRvkYtL4j4W&export=download&confirm=t'}
)
function Test-Digest($Path, $Expected) {
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) { throw "SHA-256 mismatch: $Path" }
}
foreach ($set in $sets) {
    $missing = foreach ($row in $rows | Where-Object { $_.dataset -eq $set.Dataset }) {
        $dest = [IO.Path]::GetFullPath((Join-Path $root $row.file))
        if (!$dest.StartsWith($dataRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid output path' }
        if (Test-Path -LiteralPath $dest) { Test-Digest $dest $row.raw_sha256 }
        else { [pscustomobject]@{Member=$row.member; File=$dest; Sha=$row.raw_sha256} }
    }
    if (!$missing) { continue }
    $archive = $set.Archive
    if (!$archive) {
        $archive = Join-Path $root $set.Cache
        if (!(Test-Path -LiteralPath $archive)) {
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($archive))
            $part = "$archive.$([guid]::NewGuid()).part"
            try {
                Invoke-WebRequest -UseBasicParsing -Uri $set.Url -OutFile $part
                Test-Digest $part $set.Sha
                if (!(Test-Path -LiteralPath $archive)) { [IO.File]::Move($part,$archive) }
            } finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force } }
        }
    }
    $archive = (Get-Item -LiteralPath $archive).FullName
    Test-Digest $archive $set.Sha
    $names = @(& tar.exe -tf $archive)
    if ($LASTEXITCODE -ne 0) { throw "Cannot list $archive" }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('dip-inputs-' + [guid]::NewGuid())
    [void][IO.Directory]::CreateDirectory($tmp)
    try {
        $entries = foreach ($item in $missing) {
            $member = $item.Member
            $found = @($names | Where-Object { $_ -ceq $member -or $_.EndsWith('/'+$member,[StringComparison]::Ordinal) })
            if ($found.Count -ne 1 -or $found[0] -notmatch '^(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.(png|gif)$') { throw "Missing or invalid member: $member" }
            [pscustomobject]@{Name=$found[0]; File=$item.File; Sha=$item.Sha}
        }
        $members = @($entries.Name)
        & tar.exe -xf $archive -C $tmp @members
        if ($LASTEXITCODE -ne 0) { throw "Cannot unpack $archive" }
        foreach ($entry in $entries) {
            $src = Join-Path $tmp $entry.Name
            Test-Digest $src $entry.Sha
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entry.File))
            if (!(Test-Path -LiteralPath $entry.File)) { [IO.File]::Copy($src,$entry.File) }
            Test-Digest $entry.File $entry.Sha
        }
    } finally {
        $resolved = (Get-Item -LiteralPath $tmp).FullName
        if ([IO.Path]::GetDirectoryName($resolved) -eq ([IO.Path]::GetTempPath()).TrimEnd('\') -and [IO.Path]::GetFileName($resolved) -match '^dip-inputs-[0-9a-f-]{36}$') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
Write-Output "Verified $($rows.Count) source files."
