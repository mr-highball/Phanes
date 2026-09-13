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
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/recovery-rooms-' +
    [Guid]::NewGuid().ToString('N'))
}
$unitsRoot = Join-Path $repositoryRoot 'build/recovery-rooms-units'
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
New-Item -ItemType Directory -Force -Path $unitsRoot, $binaryRoot | Out-Null

Push-Location $repositoryRoot
try {
  if (-not (Test-Path 'build/phanes.tests.styles.probe.js')) {
    throw 'Build the existing styles probe with tools/test-renderer.ps1 first.'
  }
  $arguments = @(
    '-Mdelphi', '-Fu./tools', '-Fu./src', '-Fu./vendor/wfc/tools',
    "-FU$unitsRoot", "-FE$binaryRoot",
    'tests/phanes.tests.recovery.rooms.browser.lpr'
  )
  & $NativeCompiler $arguments
  if ($LASTEXITCODE -ne 0) { throw 'The recovery rooms browser driver did not compile.' }
  $suffix = if ($IsWindows) { '.exe' } else { '' }
  $driver = Join-Path $binaryRoot "phanes.tests.recovery.rooms.browser$suffix"
  & $driver $Browser $TestUrl $EvidenceDirectory 'build/phanes.tests.styles.probe.js'
  if ($LASTEXITCODE -ne 0) {
    throw "Recovery rooms checks failed. Evidence: $EvidenceDirectory"
  }
  Write-Host "Recovery rooms evidence: $EvidenceDirectory"
} finally {
  Pop-Location
}
