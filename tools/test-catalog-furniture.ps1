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
  [Parameter(Mandatory = $true)]
  [string]$EvidencePath,
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) {
      $env:FPC_NATIVE
    } else {
      'fpc'
    }),
  [string]$EvidenceDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
  throw "Furniture geometry evidence does not exist: $resolvedEvidence"
}
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot 'build/catalog-furniture-tests'
}
$outputRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
$unitRoot = Join-Path $outputRoot 'units'
New-Item -ItemType Directory -Force $outputRoot, $unitRoot | Out-Null
$buildLog = Join-Path $outputRoot 'native-build.log'
$arguments = @(
  '-Mdelphi', '-Sh', '-O2', '-Sc',
  "-Fu$repositoryRoot/src", "-FU$unitRoot", "-FE$outputRoot",
  (Join-Path $repositoryRoot 'tests/phanes.tests.catalog.furniture.lpr')
)
& $NativeCompiler @arguments *> $buildLog
if ($LASTEXITCODE -ne 0) {
  Get-Content -LiteralPath $buildLog -Tail 40
  throw 'Furniture profile native compilation failed.'
}
$suffix = if ($IsWindows) { '.exe' } else { '' }
$executable = Join-Path $outputRoot "phanes.tests.catalog.furniture$suffix"
& $executable $repositoryRoot $resolvedEvidence |
  Tee-Object -FilePath (Join-Path $outputRoot 'native-test.log')
if ($LASTEXITCODE -ne 0) {
  throw 'Furniture profile native checks failed.'
}
