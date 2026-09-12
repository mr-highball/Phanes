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
  [Parameter(Mandatory)][string]$FpcSource,
  [Parameter(Mandatory)][string]$Win64Compiler,
  [Parameter(Mandatory)][string]$FpcConfig
)
# Optional Windows development helper when the installed WASM compiler has a
# 32-bit host and cannot address enough memory to compile CGE. Reads installed
# sources; all generated compiler files stay in this repository's ignored build/.
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot
$outputDirectory = Join-Path $repositoryRoot 'build/toolchain'
New-Item -ItemType Directory -Force "$outputDirectory/compiler-units" | Out-Null
$source = Join-Path (Resolve-Path $FpcSource) 'compiler'
$arguments = @(
  '-O2'
  '-dwasm32'
  "-Fu$source/wasm32"
  "-Fu$source/systems"
  "-Fi$source/wasm32"
  "-Fi$source"
  "-FU$outputDirectory/compiler-units"
  "-FE$outputDirectory"
  '-ofpc.exe'
  "$source/pp.pas"
)
& $Win64Compiler @arguments
if ($LASTEXITCODE -ne 0) {
  throw 'Could not build the 64-bit-host WASM compiler'
}
Copy-Item $FpcConfig "$outputDirectory/fpc.cfg" -Force
Write-Output "Add $outputDirectory to PATH for the CGE web build. Installed compiler files were not changed."
