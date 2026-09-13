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
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [string]$RuntimeJs = $(if ($env:PAS2JS_RUNTIME) { $env:PAS2JS_RUNTIME } else { 'rtl.js' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
$unitsRoot = Join-Path $repositoryRoot 'build/authoring-tool-units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force -Path $unitsRoot, $binaryRoot | Out-Null
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/authoring-' + [Guid]::NewGuid().ToString('N'))
}
Push-Location $repositoryRoot
try {
  foreach ($test in @('styles.probe', 'selection', 'audio')) {
    & $Compiler '-B' '-Tbrowser' '-Mdelphi' '-Jc' "-Ji$RuntimeJs" '-Fu./src' '-Fu./vendor/wfc/src' "-FU$unitsRoot" '-FE./build' "tests/phanes.tests.$test.lpr"
    if ($LASTEXITCODE -ne 0) { throw "Pascal $test checks did not compile." }
  }
  & $NativeCompiler '-Fu./tools' '-Fu./src' '-Fu./vendor/wfc/tools' "-FU$unitsRoot" "-FE$binaryRoot" 'tests/phanes.tests.authoring.browser.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'The Pascal authoring browser checker did not compile.' }
  $testName = if ($IsWindows) { 'phanes.tests.authoring.browser.exe' } else { 'phanes.tests.authoring.browser' }
  & (Join-Path $binaryRoot $testName) $Browser $TestUrl $EvidenceDirectory
  if ($LASTEXITCODE -ne 0) { throw "Authoring checks failed. Evidence: $EvidenceDirectory" }
} finally {
  Pop-Location
}

