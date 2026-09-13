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
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
$unitsRoot = Join-Path $repositoryRoot 'build/catalog-regional-browser-units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force -Path $unitsRoot, $binaryRoot | Out-Null
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/catalog-regional-browser-' +
    [Guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null

Push-Location $repositoryRoot
try {
  & $Compiler -B -Tbrowser -Mdelphi -Jc '-Jirtl.js' '-Fu./src' '-Fu./vendor/wfc/src' `
    "-FU$unitsRoot" "-FE$unitsRoot" 'tests/phanes.tests.catalog.regional.probe.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Regional capture placement probe did not compile.' }
  $arguments = @(
    '-B',
    '-Mdelphi',
    '-Fu./tools',
    '-Fu./src',
    '-Fu./vendor/wfc/tools',
    "-FU$unitsRoot",
    "-FE$binaryRoot",
    'tests/phanes.tests.catalog.regional.browser.lpr'
  )
  & $NativeCompiler $arguments
  if ($LASTEXITCODE -ne 0) { throw 'The regional catalog browser driver did not compile.' }
  $testName = if ($IsWindows) {
    'phanes.tests.catalog.regional.browser.exe'
  } else {
    'phanes.tests.catalog.regional.browser'
  }
  & (Join-Path $binaryRoot $testName) $Browser $TestUrl $EvidenceDirectory 2>&1 |
    Tee-Object -FilePath (Join-Path $EvidenceDirectory 'checks.log')
  $testExitCode = $LASTEXITCODE
  if ($testExitCode -ne 0) {
    throw "Regional catalog browser checks failed. Evidence: $EvidenceDirectory"
  }
  Write-Host "Regional catalog browser checks passed. Evidence: $EvidenceDirectory"
} finally {
  Pop-Location
}
