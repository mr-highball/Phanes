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
  [string]$TestUrl = 'http://127.0.0.1:4186/',
  [string]$EvidenceDirectory = '',
  [int]$TransferBytesPerSecond = 0,
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [string]$RuntimeJs = $(if ($env:PAS2JS_RUNTIME) { $env:PAS2JS_RUNTIME } else { 'rtl.js' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
$unitsRoot = Join-Path $repositoryRoot 'build/startup-test-units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force $unitsRoot, $binaryRoot | Out-Null
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/startup-' + [Guid]::NewGuid().ToString('N'))
}
Push-Location $repositoryRoot
try {
  & $Compiler '-B' '-Tbrowser' '-Mdelphi' '-Jc' "-Ji$RuntimeJs" "-FU$unitsRoot" '-FE./build' `
    'tests/phanes.tests.startup.probe.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'The Pascal startup fault injector did not compile.' }
  & $NativeCompiler '-Fu./tools' '-Fu./src' '-Fu./vendor/wfc/tools' "-FU$unitsRoot" "-FE$binaryRoot" `
    'tests/phanes.tests.startup.browser.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'The Pascal startup browser checker did not compile.' }
  $testName = if ($IsWindows) { 'phanes.tests.startup.browser.exe' } else { 'phanes.tests.startup.browser' }
  foreach ($startupCase in @('normal', 'engine-network', 'assets-network', 'catalog-network',
      'compile-failure', 'caught-initialize', 'late-initialize', 'slow-catalog', 'slow-compile',
      'part-recovery', 'part-corrupt', 'part-cancel')) {
    & (Join-Path $binaryRoot $testName) $Browser $TestUrl (Join-Path $EvidenceDirectory $startupCase) $startupCase
    if ($LASTEXITCODE -ne 0) { throw "Startup check failed: $startupCase. Evidence: $EvidenceDirectory" }
  }
  if ($TransferBytesPerSecond -gt 0) {
    & $NativeCompiler '-Fu./tools' "-FU$unitsRoot" "-FE$binaryRoot" 'tests/phanes.tests.startup.transfer.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'The Pascal transfer checker did not compile.' }
    $transferName = if ($IsWindows) { 'phanes.tests.startup.transfer.exe' } else { 'phanes.tests.startup.transfer' }
    & (Join-Path $binaryRoot $transferName) (Join-Path $repositoryRoot 'build/web') $TestUrl $TransferBytesPerSecond
    if ($LASTEXITCODE -ne 0) { throw 'The limited-rate startup transfer check failed.' }
  }
} finally {
  Pop-Location
}
