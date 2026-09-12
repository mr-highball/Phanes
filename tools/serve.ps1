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
  [string]$SiteRoot = 'build/web',
  [ValidateRange(1, 65535)][int]$Port = 4186,
  [string]$BindAddress = '127.0.0.1',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
$sourceRoot = Join-Path $repositoryRoot 'vendor/wfc/tools'
$compilerPath = (Get-Command $NativeCompiler -CommandType Application).Source
$buildInputs = @($compilerPath) + @('wfc_serve.lpr', 'wfc_serve_http.pas', 'wfc_browser_socket.pas' |
  ForEach-Object { Join-Path $sourceRoot $_ })
$inputHashes = ($buildInputs | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) -join ':'
$hasher = [Security.Cryptography.SHA256]::Create()
try {
  $buildKey = [Convert]::ToHexString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($inputHashes))).ToLowerInvariant()
} finally {
  $hasher.Dispose()
}
$unitRoot = Join-Path $repositoryRoot "build/wfc-host-units/$buildKey"
$serverName = "wfc_serve-$buildKey" + $(if ($IsWindows) { '.exe' } else { '' })
$serverPath = Join-Path $binaryRoot $serverName
New-Item -ItemType Directory -Force -Path $unitRoot, $binaryRoot | Out-Null
# Compile the pinned dependency itself. This wrapper only orchestrates FPC and
# process startup; HTTP handling remains entirely in WFC's Pascal server.
if (-not (Test-Path -LiteralPath $serverPath -PathType Leaf)) {
  & $NativeCompiler "-Fu$sourceRoot" "-FU$unitRoot" "-o$serverPath" (Join-Path $sourceRoot 'wfc_serve.lpr')
  if ($LASTEXITCODE -ne 0) {
    throw 'The pinned WFC static server failed to compile.'
  }
}
if ($BuildOnly) {
  Write-Output $serverPath
  return
}
if (-not [IO.Path]::IsPathRooted($SiteRoot)) {
  $SiteRoot = Join-Path $repositoryRoot $SiteRoot
}
$resolvedSite = (Resolve-Path -LiteralPath $SiteRoot).Path
& $serverPath --root $resolvedSite --bind $BindAddress --port $Port
if ($LASTEXITCODE -ne 0) {
  throw "The WFC preview server stopped with exit code $LASTEXITCODE."
}
