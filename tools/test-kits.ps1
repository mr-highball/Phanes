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
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$unitDirectory = Join-Path $repositoryRoot 'build/kits-test-units'
$binaryDirectory = Join-Path $repositoryRoot 'build/tools'
$logDirectory = Join-Path $repositoryRoot 'build/logs'
New-Item -ItemType Directory -Force $unitDirectory, $binaryDirectory, $logDirectory | Out-Null
foreach ($entry in @('phanes.tests.kits.critic', 'phanes.tests.kits.license.critic',
  'phanes.tests.kits.aliases.critic', 'phanes.tests.sourcehtml.critic',
  'phanes.tests.collections.critic', 'phanes.tests.streaming.critic',
  'phanes.tests.pages.critic', 'phanes.tests.obj.critic',
  'phanes.tests.obj.surface.critic', 'phanes.tests.derived.critic')) {
  $arguments = @('-B', '-Mdelphi', "-Fu$repositoryRoot/tools", "-Fu$repositoryRoot/src",
    "-FU$unitDirectory", "-FE$binaryDirectory", "$repositoryRoot/tests/$entry.lpr")
  & $NativeCompiler @arguments *> (Join-Path $logDirectory "$entry-build.log")
  if ($LASTEXITCODE -ne 0) {
    Get-Content (Join-Path $logDirectory "$entry-build.log") -Tail 30
    throw "Independent Pascal kit test failed to compile: $entry"
  }
  $executable = if ($IsWindows) { "$entry.exe" } else { $entry }
  & (Join-Path $binaryDirectory $executable) $repositoryRoot |
    Tee-Object (Join-Path $logDirectory "$entry.log")
  if ($LASTEXITCODE -ne 0) {
    throw "Independent kit checks failed: $entry"
  }
}
