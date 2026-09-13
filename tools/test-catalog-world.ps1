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
  [string]$Browser = $env:BROWSER,
  [string]$TestUrl = 'http://127.0.0.1:4297/',
  [string]$EvidenceDirectory = '',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [string]$RuntimeJs = $(if ($env:PAS2JS_RUNTIME) { $env:PAS2JS_RUNTIME } else { 'rtl.js' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
$unitsRoot = Join-Path $repositoryRoot 'build/catalog-world-units'
$probeRoot = Join-Path $repositoryRoot 'build/catalog-world-probe'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force -Path $unitsRoot, $probeRoot, $binaryRoot | Out-Null
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/catalog-world-' +
    [Guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null

Push-Location $repositoryRoot
try {
  $probeArguments = @(
    '-B',
    '-Tbrowser',
    '-Mdelphi',
    '-Jc',
    "-Ji$RuntimeJs",
    "-FU$probeRoot",
    "-FE$probeRoot",
    'tests/phanes.tests.catalog.world.probe.lpr'
  )
  & $Compiler $probeArguments
  if ($LASTEXITCODE -ne 0) { throw 'The catalog world cancellation probe did not compile.' }
  $arguments = @(
    '-B',
    '-Mdelphi',
    '-Fu./tools',
    '-Fu./src',
    '-Fu./vendor/wfc/tools',
    "-FU$unitsRoot",
    "-FE$binaryRoot",
    'tests/phanes.tests.catalog.world.browser.lpr'
  )
  & $NativeCompiler $arguments
  if ($LASTEXITCODE -ne 0) { throw 'The catalog world browser driver did not compile.' }
  $testName = if ($IsWindows) {
    'phanes.tests.catalog.world.browser.exe'
  } else {
    'phanes.tests.catalog.world.browser'
  }
  & (Join-Path $binaryRoot $testName) $Browser $TestUrl $EvidenceDirectory 2>&1 |
    Tee-Object -FilePath (Join-Path $EvidenceDirectory 'checks.log')
  $testExitCode = $LASTEXITCODE
  if ($testExitCode -ne 0) { throw "Catalog world checks failed. Evidence: $EvidenceDirectory" }
  Write-Host "Catalog world checks passed. Evidence: $EvidenceDirectory"
} finally {
  Pop-Location
}
