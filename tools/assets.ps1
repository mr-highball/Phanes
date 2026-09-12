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
  [ValidateSet('verify-kits', 'import-kits', 'import-music', 'verify-music',
    'import-materials', 'verify-materials', 'package-catalog', 'summarize-catalog',
    'stage-pages', 'prepare-regional-palette')]
  [string]$Action = 'verify-kits',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' })
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$binaryDirectory = Join-Path $repositoryRoot 'build/tools'
$unitDirectory = Join-Path $repositoryRoot 'build/tool-units'
$logDirectory = Join-Path $repositoryRoot 'build/logs'
New-Item -ItemType Directory -Force $binaryDirectory, $unitDirectory, $logDirectory | Out-Null
$arguments = @('-B', '-Mdelphi', "-Fu$PSScriptRoot", "-Fu$repositoryRoot/src", "-FU$unitDirectory", "-FE$binaryDirectory",
  (Join-Path $PSScriptRoot 'phanes.assets.lpr'))
& $NativeCompiler @arguments *> (Join-Path $logDirectory 'asset-tool-build.log')
if ($LASTEXITCODE -ne 0) {
  Get-Content (Join-Path $logDirectory 'asset-tool-build.log') -Tail 30
  throw 'Native Pascal asset tool compilation failed'
}
$executable = if ($IsWindows) { 'phanes.assets.exe' } else { 'phanes.assets' }
& (Join-Path $binaryDirectory $executable) $Action $repositoryRoot
if ($LASTEXITCODE -ne 0) {
  throw "Pascal asset command failed: $Action"
}
