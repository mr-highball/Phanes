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
$packageRoot = Join-Path $repositoryRoot 'vendor/castle-engine/packages/lazarus'
$packageFile = Join-Path $packageRoot 'castle_engine_base.lpk'
[xml]$package = Get-Content -LiteralPath $packageFile -Raw
$searchPaths = $package.CONFIG.Package.CompilerOptions.SearchPaths
$binaryDirectory = Join-Path $repositoryRoot 'build/tools'
$unitDirectory = Join-Path $repositoryRoot 'build/catalog-cge-units'
$logDirectory = Join-Path $repositoryRoot 'build/logs'
New-Item -ItemType Directory -Force $binaryDirectory, $unitDirectory, $logDirectory | Out-Null
# Castle's FPC-only localization unit uses the engine's default compiler mode.
# Every Phanes source declares its own Delphi mode explicitly.
$arguments = @('-Mobjfpc', '-Sh', '-O2', '-Sc', "-Fu$PSScriptRoot",
  "-FU$unitDirectory", "-FE$binaryDirectory")
foreach ($path in $searchPaths.OtherUnitFiles.Value.Split(';')) {
  $arguments += "-Fu$([IO.Path]::GetFullPath((Join-Path $packageRoot $path)))"
}
foreach ($path in $searchPaths.IncludeFiles.Value.Split(';')) {
  $arguments += "-Fi$([IO.Path]::GetFullPath((Join-Path $packageRoot $path)))"
}
$programs = @()
if ($WithTests) {
  $programs += Join-Path $repositoryRoot 'tests/phanes.tests.fingerprint.critic.lpr'
}
$programs += Join-Path $PSScriptRoot 'phanes.catalog.inspect.lpr'
foreach ($program in $programs) {
  $entry = [IO.Path]::GetFileNameWithoutExtension($program)
  $compileArguments = $arguments + $program
  $compileLog = Join-Path $logDirectory "$entry-build.log"
  & $NativeCompiler @compileArguments *> $compileLog
  if ($LASTEXITCODE -ne 0) {
    Get-Content $compileLog -Tail 25
    throw "Pascal Castle catalog compilation failed: $entry"
  }
  $executable = if ($IsWindows) { "$entry.exe" } else { $entry }
  & (Join-Path $binaryDirectory $executable) $repositoryRoot |
    Tee-Object (Join-Path $logDirectory "$entry.log")
  if ($LASTEXITCODE -ne 0) {
    throw "Castle catalog checks failed: $entry"
  }
}
