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
  [switch]$Regenerate,
  [ValidateSet('props', 'nature', 'equipment', 'furniture')][string]$Category = 'props',
  [string]$PublishedRoot = 'build/web',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path $repositoryRoot 'build/catalog-batch-check'
New-Item -ItemType Directory -Force $outputRoot | Out-Null
Push-Location $repositoryRoot
try {
  $suffix = if ($IsWindows) { '.exe' } else { '' }
  $arguments = @('-B', '-Mdelphi', '-Fusrc', '-Futools', '-Fuvendor/wfc/src',
    "-FU$outputRoot", "-FE$outputRoot")
  if ($Regenerate) {
    & $NativeCompiler @arguments tools/phanes.tools.catalog.batch.lpr *> "$outputRoot/generator-build.log"
    if ($LASTEXITCODE -ne 0) { throw "Batch importer compile failed: $outputRoot/generator-build.log" }
    $importArguments = @($PublishedRoot)
    if ($Category -eq 'nature') { $importArguments += '--nature' }
    if ($Category -eq 'equipment') { $importArguments += '--equipment' }
    if ($Category -eq 'furniture') { $importArguments += '--furniture' }
    & "$outputRoot/phanes.tools.catalog.batch$suffix" @importArguments
    if ($LASTEXITCODE -ne 0) { throw 'Batch importer failed' }
    if ($Category -eq 'nature') {
      & "$PSScriptRoot/assets.ps1" -Action prepare-regional-palette -NativeCompiler $NativeCompiler
    }
  }
  $testProgram = if ($Category -eq 'nature') { 'phanes.tests.catalog.nature' } else { 'phanes.tests.buildings' }
  & $NativeCompiler @arguments "tests/$testProgram.lpr" *> "$outputRoot/placement-build.log"
  if ($LASTEXITCODE -ne 0) { throw "Placement checks compile failed: $outputRoot/placement-build.log" }
  $testMode = if ($Category -eq 'equipment') { '--catalog-equipment' } else { '--catalog-batch' }
  if ($Category -eq 'furniture') { $testMode = '--catalog-furniture' }
  & "$outputRoot/$testProgram$suffix" $testMode
  if ($LASTEXITCODE -ne 0) { throw 'Batch placement checks failed' }
} finally {
  Pop-Location
}
