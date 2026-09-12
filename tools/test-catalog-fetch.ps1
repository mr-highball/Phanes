<#
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>
[CmdletBinding()]
param(
  [string]$Browser = $(if ($env:BROWSER) { $env:BROWSER } else {
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
  }),
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [ValidateRange(1, 65535)][int]$Port = 4297,
  [string]$EvidenceDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot `
    ('build/catalog-fetch-' + [Guid]::NewGuid().ToString('N'))
} elseif (-not [IO.Path]::IsPathRooted($EvidenceDirectory)) {
  $EvidenceDirectory = Join-Path $repositoryRoot $EvidenceDirectory
}
$siteRoot = Join-Path $EvidenceDirectory 'site'
$unitRoot = Join-Path $EvidenceDirectory 'units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force -Path $siteRoot, $unitRoot, $binaryRoot | Out-Null

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  $parent = Split-Path $Path -Parent
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"),
    [Text.UTF8Encoding]::new($false))
}

function Copy-Publication([string]$Target) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Target 'data'),
    (Join-Path $Target 'library/catalog'), (Join-Path $Target 'library/blobs') | Out-Null
  Copy-Item -LiteralPath (Join-Path $repositoryRoot 'build/web/data/library-files.json') `
    -Destination (Join-Path $Target 'data/library-files.json')
  $index = Get-Content -Raw (Join-Path $Target 'data/library-files.json') | ConvertFrom-Json
  $kitIds = @('quaternius-low-poly-food-pack-surface-v1', 'kaykit-furniture-bits-1-0')
  foreach ($kitId in $kitIds) {
    $kit = $index.kits | Where-Object id -eq $kitId
    Copy-Item -LiteralPath (Join-Path $repositoryRoot ('build/web/' + $kit.url)) `
      -Destination (Join-Path $Target $kit.url)
    $manifest = Get-Content -Raw (Join-Path $Target $kit.url) | ConvertFrom-Json
    $modelPattern = if ($kitId -like 'quaternius*') { 'soysauce' } else { 'rug_rectangle_A' }
    $model = $manifest.models | Where-Object id -match $modelPattern
    foreach ($file in @($model.files) + @($manifest.notice)) {
      Copy-Item -LiteralPath (Join-Path $repositoryRoot ('build/web/' + $file.url)) `
        -Destination (Join-Path $Target $file.url)
    }
  }
  Copy-Item -LiteralPath (Join-Path $unitRoot 'phanes.tests.catalog.fetch.probe.js') `
    -Destination (Join-Path $Target 'catalog-fetch-probe.js')
  Write-Utf8NoBom (Join-Path $Target 'catalog-fetch-probe.html') `
    '<!doctype html><meta charset="utf-8"><title>Catalog fetch probe</title><script src="catalog-fetch-probe.js"></script><script>rtl.run();</script>'
}

function Rewrite-Manifest([string]$Target, [string]$KitId, [scriptblock]$Change) {
  $indexPath = Join-Path $Target 'data/library-files.json'
  $index = Get-Content -Raw $indexPath | ConvertFrom-Json
  $kit = $index.kits | Where-Object id -eq $KitId
  $oldPath = Join-Path $Target $kit.url
  $manifest = Get-Content -Raw $oldPath | ConvertFrom-Json
  & $Change $manifest
  $json = $manifest | ConvertTo-Json -Depth 20 -Compress
  $temporary = Join-Path $Target 'library/catalog/changed.json'
  Write-Utf8NoBom $temporary ($json + "`n")
  $hash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
  $newUrl = "library/catalog/$KitId-$hash.json"
  Move-Item -LiteralPath $temporary -Destination (Join-Path $Target $newUrl)
  $kit.url = $newUrl
  $kit.sha256 = $hash
  $kit.bytes = (Get-Item -LiteralPath (Join-Path $Target $newUrl)).Length
  Write-Utf8NoBom $indexPath (($index | ConvertTo-Json -Depth 20 -Compress) + "`n")
}

Push-Location $repositoryRoot
$serverProcess = $null
try {
  & $Compiler -B -Tbrowser -Mdelphi -Jc '-Jirtl.js' '-Fu./src' "-FU$unitRoot" `
    "-FE$unitRoot" 'tests/phanes.tests.catalog.fetch.probe.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Catalog fetch browser probe did not compile.' }
  & $NativeCompiler '-Fu./tools' '-Fu./src' '-Fu./vendor/wfc/tools' "-FU$unitRoot" `
    "-FE$binaryRoot" 'tests/phanes.tests.catalog.fetch.browser.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Catalog fetch browser checker did not compile.' }
  & $NativeCompiler '-Fu./tools' "-FU$unitRoot" "-FE$binaryRoot" `
    'tests/phanes.tests.catalog.fetch.fixture.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Catalog fetch fixture publisher did not compile.' }

  Copy-Publication $siteRoot
  Copy-Publication (Join-Path $siteRoot 'project')
  foreach ($caseName in @('corrupt', 'missing', 'oversize', 'invalid')) {
    Copy-Publication (Join-Path $siteRoot $caseName)
  }
  $fixturePublisher = Join-Path $binaryRoot `
    ('phanes.tests.catalog.fetch.fixture' + $(if ($IsWindows) { '.exe' } else { '' }))
  & $fixturePublisher (Join-Path $siteRoot 'bounded')
  if ($LASTEXITCODE -ne 0) { throw 'Catalog fetch bounded fixture publication failed.' }
  Copy-Item -LiteralPath (Join-Path $unitRoot 'phanes.tests.catalog.fetch.probe.js') `
    -Destination (Join-Path $siteRoot 'bounded/catalog-fetch-probe.js')
  Write-Utf8NoBom (Join-Path $siteRoot 'bounded/catalog-fetch-probe.html') `
    '<!doctype html><meta charset="utf-8"><title>Bounded catalog fetch probe</title><script src="catalog-fetch-probe.js"></script><script>rtl.run();</script>'
  $badBlob = Join-Path $siteRoot `
    'corrupt/library/blobs/4a131739d867c3b3143f2108a04b6c6f7dfd86b8aeb5c30081b85ccaee393cb0'
  [IO.File]::WriteAllBytes($badBlob, [byte[]]::new(11880))
  Remove-Item -LiteralPath (Join-Path $siteRoot `
    'missing/library/blobs/10eb71fc2b20b056b6186526d451ee0a560c425495402d7818f4413795aba506')
  Rewrite-Manifest (Join-Path $siteRoot 'oversize') `
    'quaternius-low-poly-food-pack-surface-v1' {
      param($manifest)
      $model = $manifest.models | Where-Object id -match 'soysauce'
      $model.files[0].bytes = 67108865
      $model.downloadBytes = 67108865
    }
  Rewrite-Manifest (Join-Path $siteRoot 'invalid') `
    'quaternius-low-poly-food-pack-surface-v1' {
      param($manifest)
      $model = $manifest.models | Where-Object id -match 'soysauce'
      $model.path = '../escape.glb'
      $model.files[0].path = '../escape.glb'
    }

  $serverPath = & './tools/serve.ps1' -BuildOnly -NativeCompiler $NativeCompiler |
    Select-Object -Last 1
  $serverProcess = Start-Process -FilePath $serverPath -ArgumentList @(
    '--root', $siteRoot, '--bind', '127.0.0.1', '--port', "$Port") -PassThru `
    -WindowStyle Hidden -RedirectStandardOutput (Join-Path $EvidenceDirectory 'server.log') `
    -RedirectStandardError (Join-Path $EvidenceDirectory 'server-error.log')
  for ($attempt = 0; $attempt -lt 100; $attempt++) {
    try {
      $connection = [Net.Sockets.TcpClient]::new('127.0.0.1', $Port)
      $connection.Dispose()
      break
    } catch {
      Start-Sleep -Milliseconds 100
    }
  }
  if (-not $serverProcess -or $serverProcess.HasExited) {
    throw 'Catalog fetch fixture server did not start.'
  }
  $driver = Join-Path $binaryRoot `
    ('phanes.tests.catalog.fetch.browser' + $(if ($IsWindows) { '.exe' } else { '' }))
  $runs = @(
    @('', 'normal'), @('project/', 'normal'), @('corrupt/', 'corrupt'),
    @('missing/', 'missing'), @('oversize/', 'oversize'), @('invalid/', 'invalid'),
    @('bounded/', 'bounded'), @('bounded/', 'stream-index'),
    @('bounded/', 'stream-manifest'), @('bounded/', 'stream-model'),
    @('bounded/', 'stream-error'))
  $runNumber = 0
  foreach ($run in $runs) {
    $runNumber++
    if (($run[1] -eq 'bounded') -or ($run[1] -like 'stream-*')) {
      $url = "http://127.0.0.1:$Port/bounded/catalog-fetch-probe.html?budget=12"
    } else {
      $url = "http://127.0.0.1:$Port/$($run[0])catalog-fetch-probe.html"
    }
    & $driver $Browser $url (Join-Path $EvidenceDirectory "browser-$runNumber") $run[1]
    if ($LASTEXITCODE -ne 0) {
      throw "Catalog fetch browser case $($run[1]) failed. Evidence: $EvidenceDirectory"
    }
  }
  Write-Output "Catalog fetch checks passed. Evidence: $EvidenceDirectory"
} finally {
  if ($serverProcess -and -not $serverProcess.HasExited) {
    Stop-Process -Id $serverProcess.Id
    $serverProcess.WaitForExit()
  }
  Pop-Location
}
