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
  [switch]$WithTests,
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$binaryDirectory = Join-Path $repositoryRoot 'build/tools'
$unitDirectory = Join-Path $repositoryRoot 'build/review-units'
$logDirectory = Join-Path $repositoryRoot 'build/logs'
New-Item -ItemType Directory -Force $binaryDirectory, $unitDirectory, $logDirectory | Out-Null
$programs = @('tools/phanes.reviews.lpr')
if ($WithTests) {
  $programs += 'tests/phanes.tests.reviews.lpr'
}
foreach ($program in $programs) {
  $arguments = @('-B', '-Mdelphi', "-Fu$PSScriptRoot", "-FU$unitDirectory", "-FE$binaryDirectory",
    (Join-Path $repositoryRoot $program))
  & $NativeCompiler @arguments *> (Join-Path $logDirectory 'review-tool-build.log')
  if ($LASTEXITCODE -ne 0) {
    Get-Content (Join-Path $logDirectory 'review-tool-build.log') -Tail 30
    throw "Native Pascal review tool compilation failed: $program"
  }
}
$suffix = if ($IsWindows) { '.exe' } else { '' }
if ($WithTests) {
  & (Join-Path $binaryDirectory "phanes.tests.reviews$suffix") $repositoryRoot
  if ($LASTEXITCODE -ne 0) {
    throw 'Critic gate regression tests failed'
  }
}
& (Join-Path $binaryDirectory "phanes.reviews$suffix") check $repositoryRoot |
  Tee-Object -FilePath (Join-Path $logDirectory 'critic-gate.log')
if ($LASTEXITCODE -ne 0) {
  throw 'Critic gate has not passed. See build/logs/critic-gate.log for feature feedback.'
}
