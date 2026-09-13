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
  [string]$EvidenceRoot = '',
  [ValidateSet('all', 'queued-save', 'read-failure', 'read-late-abort',
    'read-sync-throw', 'size-preflight')]
  [string]$Case = 'all',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
$unitsRoot = Join-Path $repositoryRoot 'build/recovery-storage-units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
if (-not $EvidenceRoot) {
  $EvidenceRoot = Join-Path $repositoryRoot ('build/recovery-storage-' +
    [Guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Force -Path $unitsRoot, $binaryRoot, $EvidenceRoot | Out-Null
$cases = if ($Case -eq 'all') {
  @('queued-save', 'read-failure', 'read-late-abort', 'read-sync-throw',
    'size-preflight')
} else {
  @($Case)
}

Push-Location $repositoryRoot
try {
  $probeArguments = @(
    '-B', '-Tbrowser', '-Mdelphi', '-Jc', '-Jirtl.js', '-Fu./src',
    '-Fu./vendor/wfc/src', "-FU$unitsRoot", '-FE./build',
    'tests/phanes.tests.recovery.storage.probe.lpr'
  )
  & $Compiler $probeArguments
  if ($LASTEXITCODE -ne 0) { throw 'The recovery storage probe did not compile.' }

  $driverArguments = @(
    '-Mdelphi', '-Fu./tools', '-Fu./src', '-Fu./vendor/wfc/tools',
    "-FU$unitsRoot", "-FE$binaryRoot",
    'tests/phanes.tests.recovery.storage.browser.lpr'
  )
  & $NativeCompiler $driverArguments
  if ($LASTEXITCODE -ne 0) { throw 'The recovery storage browser driver did not compile.' }

  $driver = Join-Path $binaryRoot 'phanes.tests.recovery.storage.browser.exe'
  foreach ($testCase in $cases) {
    $caseEvidence = Join-Path $EvidenceRoot $testCase
    $runArguments = @(
      $Browser, $TestUrl, $caseEvidence,
      'build/phanes.tests.recovery.storage.probe.js', $testCase
    )
    & $driver $runArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Recovery storage case failed: $testCase. Evidence: $caseEvidence"
    }
  }
  Write-Host "Recovery storage evidence: $EvidenceRoot"
} finally {
  Pop-Location
}
