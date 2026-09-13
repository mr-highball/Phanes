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
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$WebCompiler = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$packageRoot = Join-Path $repositoryRoot 'vendor/castle-engine/packages/lazarus'
[xml]$package = Get-Content -LiteralPath (Join-Path $packageRoot 'castle_engine_base.lpk') -Raw
$searchPaths = $package.CONFIG.Package.CompilerOptions.SearchPaths
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
$nativeUnits = Join-Path $repositoryRoot 'build/catalog-files-units'
$webUnits = Join-Path $repositoryRoot 'build/catalog-files-wasm-units'
$logRoot = Join-Path $repositoryRoot 'build/logs'
New-Item -ItemType Directory -Force $binaryRoot, $nativeUnits, $webUnits, $logRoot | Out-Null
$arguments = @('-Mobjfpc', '-Sh', '-O2', '-Sc', "-Fu$PSScriptRoot",
  "-Fu$repositoryRoot/cge/code")
foreach ($path in $searchPaths.OtherUnitFiles.Value.Split(';')) {
  $arguments += "-Fu$([IO.Path]::GetFullPath((Join-Path $packageRoot $path)))"
}
foreach ($path in $searchPaths.IncludeFiles.Value.Split(';')) {
  $arguments += "-Fi$([IO.Path]::GetFullPath((Join-Path $packageRoot $path)))"
}
$nativeLog = Join-Path $logRoot 'catalog-files-native-build.log'
& $NativeCompiler @arguments "-FU$nativeUnits" "-FE$binaryRoot" `
  (Join-Path $repositoryRoot 'tests/phanes.tests.catalog.files.lpr') *> $nativeLog
if ($LASTEXITCODE -ne 0) {
  Get-Content -LiteralPath $nativeLog -Tail 20
  throw 'Catalog filesystem native compilation failed.'
}
$suffix = if ($IsWindows) { '.exe' } else { '' }
& (Join-Path $binaryRoot "phanes.tests.catalog.files$suffix") $repositoryRoot |
  Tee-Object -FilePath (Join-Path $logRoot 'catalog-files-native-test.log')
if ($LASTEXITCODE -ne 0) { throw 'Catalog filesystem checks failed.' }

if ($WebCompiler) {
  # The Lazarus package describes native paths. Add the pinned WASI-specific
  # include and JOB source paths when checking the ArrayBuffer bridge.
  $webLog = Join-Path $logRoot 'catalog-files-web-build.log'
  & $WebCompiler @arguments "-FU$webUnits" `
    "-Fi$repositoryRoot/vendor/castle-engine/src/base/wasi" `
    "-Fu$repositoryRoot/vendor/castle-engine/src/base_rendering/web" `
    (Join-Path $repositoryRoot 'cge/code/phanes.catalog.files.pas') *> $webLog
  if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $webLog -Tail 20
    throw 'Catalog filesystem WASI compilation failed.'
  }
  Write-Output 'Catalog filesystem WASI bridge compiled; browser execution remains a separate check.'
}
