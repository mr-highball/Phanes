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
  [string]$SiteRoot = 'build/web',
  [string]$UnitsRoot = 'build/host-units',
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [string]$RuntimeJs = $(if ($env:PAS2JS_RUNTIME) { $env:PAS2JS_RUNTIME } else { 'rtl.js' }),
  [string]$RtlRoot = $env:PAS2JS_RTL,
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string[]]$CompilerOptions = @()
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not [IO.Path]::IsPathRooted($SiteRoot)) {
  $SiteRoot = Join-Path $repositoryRoot $SiteRoot
}
if (-not [IO.Path]::IsPathRooted($UnitsRoot)) {
  $UnitsRoot = Join-Path $repositoryRoot $UnitsRoot
}
$outputRoot = [IO.Path]::GetFullPath($SiteRoot)
$unitsRoot = [IO.Path]::GetFullPath($UnitsRoot)
New-Item -ItemType Directory -Force $unitsRoot | Out-Null
& $NativeCompiler "-Fu$repositoryRoot/tools" "-FU$unitsRoot" "-FE$unitsRoot" `
  (Join-Path $repositoryRoot 'tools/phanes.tools.webparts.lpr')
if ($LASTEXITCODE -ne 0) { throw 'Pascal startup part publisher did not compile.' }
$partsTool = Join-Path $unitsRoot ('phanes.tools.webparts' + $(if ($IsWindows) { '.exe' } else { '' }))
& $partsTool $outputRoot
if ($LASTEXITCODE -ne 0) { throw 'Pascal startup part publication failed.' }
$partsRevision = (Get-FileHash (Join-Path $outputRoot 'data/runtime-parts.json') -Algorithm SHA256).Hash.ToLower()
$partsJson = ([IO.File]::ReadAllText((Join-Path $outputRoot 'data/runtime-parts.json')) |
  ConvertFrom-Json | ConvertTo-Json -Depth 20 -Compress).Replace("'", "''")
$engineRevision = (Get-FileHash (Join-Path $outputRoot 'phanes.wasm') -Algorithm SHA256).Hash.ToLower()
$dataRevision = (Get-FileHash (Join-Path $outputRoot 'phanes_data.zip') -Algorithm SHA256).Hash.ToLower()
$assetConstants = @"
const
  EngineAssetUrl = 'phanes.wasm?revision=$engineRevision';
  DataAssetUrl = 'phanes_data.zip?revision=$dataRevision';
  StartupPartsJson = '$partsJson';
"@
[IO.File]::WriteAllText((Join-Path $unitsRoot 'phanes.host.assets.inc'),
  $assetConstants.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
$arguments = @('-B', '-Tbrowser', '-Mdelphi', '-Jc', "-Ji$RuntimeJs",
  "-Fi$unitsRoot", "-FU$unitsRoot", "-FE$unitsRoot")
if ($RtlRoot) {
  $arguments += "-Fu$RtlRoot/packages/*/src"
}
foreach ($entry in @('phanes.startup.browser', 'phanes.host.engine')) {
  & $Compiler @CompilerOptions @arguments (Join-Path $repositoryRoot "src/$entry.lpr")
  if ($LASTEXITCODE -ne 0) { throw "Pascal startup compilation failed: $entry" }
}
$startupPath = Join-Path $unitsRoot 'phanes.startup.browser.js'
$startupCode = [IO.File]::ReadAllText($startupPath)
[IO.File]::WriteAllText((Join-Path $outputRoot 'phanes.startup.browser.js'),
  "(() => {`n$startupCode`nrtl.run();`n})();`n",
  [Text.UTF8Encoding]::new($false))

# JOB's global registry assumes CacheStorage exists, although it is optional
# on LAN HTTP. Adapt generated output only; retain the pinned dependency.
$hostCode = [IO.File]::ReadAllText((Join-Path $unitsRoot 'phanes.host.engine.js'))
$hostCode = $hostCode.Replace('this.RegisterGlobalObject(caches,"caches");',
  'if (typeof caches !== "undefined") this.RegisterGlobalObject(caches,"caches");')
[IO.File]::WriteAllText((Join-Path $outputRoot 'phanes.js'), $hostCode,
  [Text.UTF8Encoding]::new($false))
& $partsTool bind $outputRoot $partsRevision
if ($LASTEXITCODE -ne 0) { throw 'Pascal startup host binding failed.' }
Write-Output 'Pascal engine host and startup UI built.'
