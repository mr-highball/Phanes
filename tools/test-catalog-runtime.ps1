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
  [Parameter(Mandatory)][string]$Browser,
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [ValidateRange(1,65535)][int]$Port = 4299,
  [string]$EvidenceDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/catalog-render-' + [Guid]::NewGuid().ToString('N'))
} elseif (-not [IO.Path]::IsPathRooted($EvidenceDirectory)) {
  $EvidenceDirectory = Join-Path $repositoryRoot $EvidenceDirectory
}
$projectRoot = Join-Path $repositoryRoot 'build/catalog-runtime-wrapper-project'
$buildRoot = Join-Path $repositoryRoot 'build/catalog-runtime-wrapper-build'
$siteRoot = Join-Path $buildRoot 'castle-engine-output/web/dist'
$unitsRoot = Join-Path $EvidenceDirectory 'units'
$serverProcess = $null
$previousEngine = $env:CASTLE_ENGINE_PATH
$sourcePaths = @(
  'cge/code/phanes.catalog.files.pas', 'cge/code/phanes.catalog.scene.pas',
  'cge/code/phanes.catalog.paths.pas', 'cge/code/phanes.catalog.shared.files.pas',
  'src/phanes.catalog.fetch.pas', 'src/phanes.catalog.admission.pas',
  'tests/phanes.tests.catalog.fetch.probe.lpr',
  'tests/catalog-runtime/CastleEngineManifest.xml',
  'tests/catalog-runtime/code/phanes.tests.catalog.runtime.pas',
  'tests/catalog-runtime/probe.html', 'tests/phanes.tests.catalog.runtime.browser.lpr',
  'tools/test-catalog-runtime.ps1'
)
$sourceHashes = [ordered]@{}
foreach ($sourcePath in $sourcePaths) {
  $sourceHashes[$sourcePath] = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $sourcePath) `
    -Algorithm SHA256).Hash.ToLowerInvariant()
}
New-Item -ItemType Directory -Force $EvidenceDirectory, $projectRoot, $unitsRoot | Out-Null
Push-Location $repositoryRoot
try {
  Copy-Item -LiteralPath 'tests/catalog-runtime/CastleEngineManifest.xml' -Destination $projectRoot -Force
  foreach ($directory in @('code','data')) {
    Copy-Item -LiteralPath "tests/catalog-runtime/$directory" -Destination $projectRoot -Recurse -Force
  }
  $env:CASTLE_ENGINE_PATH = Join-Path $repositoryRoot 'vendor/castle-engine'
  $castleTool = Join-Path $env:CASTLE_ENGINE_PATH 'tools/build-tool/castle-engine.exe'
  if (-not $IsWindows) { $castleTool = $castleTool.Substring(0,$castleTool.Length-4) }
  & $castleTool "--project=$projectRoot" generate-program *> (Join-Path $EvidenceDirectory 'generate.log')
  if ($LASTEXITCODE -ne 0) { throw 'Catalog renderer project generation failed.' }
  & $castleTool "--project=$projectRoot" "--output=$buildRoot" --target=web --mode=release compile `
    *> (Join-Path $EvidenceDirectory 'build.log')
  if ($LASTEXITCODE -ne 0) { throw 'Catalog renderer build failed; inspect build.log.' }
  & $Compiler -B -Tbrowser -Mdelphi -Jc '-Jirtl.js' '-Fu./src' "-FU$unitsRoot" "-FE$unitsRoot" `
    'tests/phanes.tests.catalog.fetch.probe.lpr' *> (Join-Path $EvidenceDirectory 'fetch-build.log')
  if ($LASTEXITCODE -ne 0) { throw 'Catalog fetch probe compilation failed.' }
  $probe = [IO.File]::ReadAllText((Join-Path $unitsRoot 'phanes.tests.catalog.fetch.probe.js'))
  [IO.File]::WriteAllText((Join-Path $siteRoot 'catalog-fetch.js'),
    "(()=>{`n$probe`nrtl.run();})();`n", [Text.UTF8Encoding]::new($false))
  Copy-Item -LiteralPath 'tests/catalog-runtime/probe.html' -Destination (Join-Path $siteRoot 'index.html')
  New-Item -ItemType Directory -Force (Join-Path $siteRoot 'data'),
    (Join-Path $siteRoot 'library/catalog'), (Join-Path $siteRoot 'library/blobs') | Out-Null
  Copy-Item -LiteralPath 'build/web/data/library-files.json' -Destination (Join-Path $siteRoot 'data/library-files.json')
  $index = Get-Content -Raw -LiteralPath 'build/web/data/library-files.json' | ConvertFrom-Json
  $models = @(
    @('quaternius-low-poly-food-pack-surface-v1','quaternius-low-poly-food-pack-surface-v1/soysauce-2882b4c31b'),
    @('kaykit-furniture-bits-1-0','kaykit-furniture-bits-1-0/gltf/rug_rectangle_A'),
    @('kaykit-furniture-bits-1-0','kaykit-furniture-bits-1-0/gltf/book_single'),
    @('quaternius-furniture-low-poly-surface-v1',
      'quaternius-furniture-low-poly-surface-v1/vase2-2bf7766b41')
  )
  foreach ($selection in $models) {
    $kits = @($index.kits | Where-Object id -eq $selection[0])
    if ($kits.Count -ne 1) { throw 'Fixture kit is missing or ambiguous.' }
    $kit = $kits[0]
    Copy-Item -LiteralPath (Join-Path 'build/web' $kit.url) -Destination (Join-Path $siteRoot $kit.url)
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $siteRoot $kit.url) | ConvertFrom-Json
    $matches = @($manifest.models | Where-Object id -eq $selection[1])
    if ($matches.Count -ne 1) { throw 'Fixture model is missing or ambiguous.' }
    foreach ($file in @($matches[0].files) + @($manifest.notice)) {
      Copy-Item -LiteralPath (Join-Path 'build/web' $file.url) -Destination (Join-Path $siteRoot $file.url)
    }
  }
  & $NativeCompiler '-Fu./tools' '-Fu./vendor/wfc/tools' "-FU$unitsRoot" "-FE$unitsRoot" `
    'tests/phanes.tests.catalog.runtime.browser.lpr' *> (Join-Path $EvidenceDirectory 'driver-build.log')
  if ($LASTEXITCODE -ne 0) { throw 'Catalog browser driver compilation failed.' }
  $server = & './tools/serve.ps1' -BuildOnly -NativeCompiler $NativeCompiler | Select-Object -Last 1
  $serverProcess = Start-Process -FilePath $server -ArgumentList @(
    '--root',$siteRoot,'--bind','127.0.0.1','--port',"$Port") -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $EvidenceDirectory 'server.log') `
    -RedirectStandardError (Join-Path $EvidenceDirectory 'server-error.log')
  $suffix = if ($IsWindows) { '.exe' } else { '' }
  & (Join-Path $unitsRoot "phanes.tests.catalog.runtime.browser$suffix") $Browser `
    "http://127.0.0.1:$Port/" $EvidenceDirectory |
    Tee-Object -FilePath (Join-Path $EvidenceDirectory 'checks.log')
  if ($LASTEXITCODE -ne 0) { throw 'Catalog runtime browser verification failed.' }
  foreach ($sourcePath in $sourcePaths) {
    $currentHash = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $sourcePath) `
      -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($currentHash -ne $sourceHashes[$sourcePath]) {
      throw "Source changed during catalog verification: $sourcePath"
    }
  }
  $artifactHashes = [ordered]@{}
  foreach ($artifact in @('catalogruntime.wasm','catalogruntime.js',
    'catalogruntime_data.zip','catalog-fetch.js','index.html')) {
    $artifactHashes[$artifact] = (Get-FileHash -LiteralPath (Join-Path $siteRoot $artifact) `
      -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $engineCommit = & git -C $env:CASTLE_ENGINE_PATH rev-parse HEAD
  if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the tested Castle engine commit.' }
  $provenance = [ordered]@{
    schemaVersion = 1; digestMode = 'SHA-256 of raw file bytes'
    engineCommit = "$engineCommit"; sourceFiles = $sourceHashes
    runtimeFiles = $artifactHashes; evidence = 'evidence.json'
  }
  [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'provenance.json'),
    ($provenance | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
} finally {
  if ($serverProcess -and -not $serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id }
  $env:CASTLE_ENGINE_PATH = $previousEngine
  Pop-Location
}
