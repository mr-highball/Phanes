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
  [ValidateSet('recovery', 'storage-denied', 'houses', 'supported-house', 'lighting',
    'put-throw', 'abort', 'late-error', 'late-success', 'put-throw-phone',
    'put-throw-house-phone', 'modular', 'landforms', 'entry-cancel', 'surface-sweep')]
  [string]$Case = 'recovery',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [string]$RuntimeJs = $(if ($env:PAS2JS_RUNTIME) { $env:PAS2JS_RUNTIME } else { 'rtl.js' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
$unitsRoot = Join-Path $repositoryRoot 'build/renderer-tool-units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force -Path $unitsRoot, $binaryRoot | Out-Null
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/renderer-' + [Guid]::NewGuid().ToString('N'))
}
Push-Location $repositoryRoot
try {
  $criticCase = $Case -in @('put-throw', 'abort', 'late-error', 'late-success',
    'put-throw-phone', 'put-throw-house-phone')
  $probes = if ($criticCase) { @('recovery.critic') } else { @('styles', 'session', 'storage') }
  if ($Case -eq 'landforms') { $probes += 'landforms' }
  if ($Case -eq 'entry-cancel') { $probes += 'recovery.entry' }
  foreach ($probe in $probes) {
    & $Compiler '-B' '-Tbrowser' '-Mdelphi' '-Jc' "-Ji$RuntimeJs" '-Fu./src' '-Fu./vendor/wfc/src' "-FU$unitsRoot" '-FE./build' "tests/phanes.tests.$probe.probe.lpr"
    if ($LASTEXITCODE -ne 0) { throw 'The Pascal browser instrumentation did not compile.' }
  }
  $driver = if ($criticCase) { 'phanes.tests.recovery.critic.browser' } else { 'phanes.tests.renderer.browser' }
  if ($Case -eq 'landforms') { $driver = 'phanes.tests.landforms.browser' }
  & $NativeCompiler '-Fu./tools' '-Fu./src' '-Fu./vendor/wfc/tools' "-FU$unitsRoot" "-FE$binaryRoot" "tests/$driver.lpr"
  if ($LASTEXITCODE -ne 0) { throw 'The Pascal renderer browser checker did not compile.' }
  $testName = if ($IsWindows) { "$driver.exe" } else { $driver }
  if ($criticCase) {
    & (Join-Path $binaryRoot $testName) $Browser $TestUrl $EvidenceDirectory 'build/phanes.tests.recovery.critic.probe.js' $Case
  } else {
    & (Join-Path $binaryRoot $testName) $Browser $TestUrl $EvidenceDirectory $Case
  }
  if ($LASTEXITCODE -ne 0) { throw "Renderer checks failed. Evidence: $EvidenceDirectory" }
} finally {
  Pop-Location
}
