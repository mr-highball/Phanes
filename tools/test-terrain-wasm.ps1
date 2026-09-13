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
  [string]$WasmCompiler = $(if ($env:FPC_WASM) { $env:FPC_WASM } else { 'fpc' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$unitDirectory = Join-Path $repositoryRoot 'build/terrain-wasm-units'
$binaryDirectory = Join-Path $repositoryRoot 'build/terrain-wasm'
$logDirectory = Join-Path $repositoryRoot 'build/logs'
New-Item -ItemType Directory -Force $unitDirectory, $binaryDirectory, $logDirectory | Out-Null
$arguments = @('-Pwasm32', '-Twasip1', '-B', '-O2', '-Mdelphi', "-Fu$repositoryRoot/src", "-Fu$repositoryRoot/tests",
  "-Fu$repositoryRoot/vendor/wfc/src", "-FU$unitDirectory", "-FE$binaryDirectory",
  "$repositoryRoot/tests/phanes.tests.terrain.lpr")
& $WasmCompiler @arguments *> (Join-Path $logDirectory 'terrain-wasm-tests-build.log')
if ($LASTEXITCODE -ne 0) {
  Get-Content (Join-Path $logDirectory 'terrain-wasm-tests-build.log') -Tail 30
  throw 'FPC WebAssembly terrain core tests failed to compile'
}
& node (Join-Path $PSScriptRoot 'test-terrain-wasm.cjs') | Tee-Object (Join-Path $logDirectory 'terrain-wasm-tests.log')
if ($LASTEXITCODE -ne 0) {
  throw 'WebAssembly terrain core checks failed'
}
