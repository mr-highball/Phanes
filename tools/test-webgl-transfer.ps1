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
  [string]$Browser = $env:BROWSER,
  [string]$TestUrl = '',
  [string]$EvidenceDirectory = '',
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$EnginePath = '',
  [string]$BuildDirectory = '',
  [string]$WebToolchainDirectory = '',
  [ValidateRange(1, 65535)][int]$Port = 4294,
  [switch]$RequireSignedRangeGuard
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (-not $Browser) { throw 'Set BROWSER or pass -Browser with a Chromium executable.' }
if (-not $TestUrl -and -not $EnginePath) {
  throw 'Pass -TestUrl for a built probe or -EnginePath to build and run one.'
}
if ($TestUrl -and $EnginePath) {
  throw 'Pass either -TestUrl or -EnginePath, not both.'
}
$binaryRoot = Join-Path $repositoryRoot 'build/tools'
if (-not $EvidenceDirectory) {
  $EvidenceDirectory = Join-Path $repositoryRoot ('build/webgl-transfer-' + [Guid]::NewGuid().ToString('N'))
} elseif (-not [IO.Path]::IsPathRooted($EvidenceDirectory)) {
  $EvidenceDirectory = Join-Path $repositoryRoot $EvidenceDirectory
}
$unitsRoot = Join-Path $EvidenceDirectory 'tool-units'
New-Item -ItemType Directory -Force -Path $unitsRoot, $binaryRoot | Out-Null
$serverProcess = $null
Push-Location $repositoryRoot
try {
  New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
  & $NativeCompiler '-Fu./tools' '-Fu./src' '-Fu./vendor/wfc/tools' `
    "-FU$unitsRoot" "-FE$binaryRoot" 'tests/phanes.tests.webgl.transfer.browser.lpr'
  if ($LASTEXITCODE -ne 0) {
    throw 'The Pascal WebGL transfer browser checker did not compile.'
  }
  $testName = 'phanes.tests.webgl.transfer.browser' +
    $(if ($IsWindows) { '.exe' } else { '' })

  $engineSourceHash = $null
  $wasmHash = $null
  $generationArguments = $null
  $buildArguments = $null
  if ($EnginePath) {
    $resolvedEnginePath = (Resolve-Path -LiteralPath $EnginePath).Path
    $castleEngineName = 'castle-engine' + $(if ($IsWindows) { '.exe' } else { '' })
    $castleEngineTool = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot `
      "vendor/castle-engine/tools/build-tool/$castleEngineName")).Path
    if (-not $BuildDirectory) {
      $BuildDirectory = Join-Path $repositoryRoot `
        ('build/webgl-transfer-probe-' + [Guid]::NewGuid().ToString('N'))
    } elseif (-not [IO.Path]::IsPathRooted($BuildDirectory)) {
      $BuildDirectory = Join-Path $repositoryRoot $BuildDirectory
    }
    $generatedProjectDirectory = $BuildDirectory + '-project'
    New-Item -ItemType Directory -Force -Path $generatedProjectDirectory | Out-Null
    Copy-Item -LiteralPath 'tests/webgl-transfer/CastleEngineManifest.xml' `
      -Destination $generatedProjectDirectory
    Copy-Item -LiteralPath 'tests/webgl-transfer/code' `
      -Destination $generatedProjectDirectory -Recurse
    Copy-Item -LiteralPath 'tests/webgl-transfer/data' `
      -Destination $generatedProjectDirectory -Recurse
    $generationArguments = @(
      "--project=$generatedProjectDirectory"
      'generate-program'
    )
    $buildArguments = @(
      "--project=$generatedProjectDirectory"
      "--output=$BuildDirectory"
      '--target=web'
      '--mode=release'
      '--compiler-option=-B'
    )
    if ($RequireSignedRangeGuard) {
      $buildArguments += '--compiler-option=-dPHANES_WEBGL_SIGNED_RANGE_GUARD'
    }
    $buildArguments += 'compile'
    $previousEnginePath = $env:CASTLE_ENGINE_PATH
    $previousPath = $env:PATH
    try {
      $env:CASTLE_ENGINE_PATH = $resolvedEnginePath
      if ($WebToolchainDirectory) {
        $resolvedWebToolchain = (Resolve-Path -LiteralPath $WebToolchainDirectory).Path
        $env:PATH = $resolvedWebToolchain + [IO.Path]::PathSeparator + $previousPath
      }
      & $castleEngineTool @generationArguments 2>&1 |
        Tee-Object -FilePath (Join-Path $EvidenceDirectory 'build.log')
      if ($LASTEXITCODE -ne 0) {
        throw "The WebGL transfer project did not generate. Evidence: $EvidenceDirectory"
      }
      & $castleEngineTool @buildArguments 2>&1 |
        Tee-Object -FilePath (Join-Path $EvidenceDirectory 'build.log') -Append
      if ($LASTEXITCODE -ne 0) {
        throw "The WebGL transfer probe did not compile. Evidence: $EvidenceDirectory"
      }
    } finally {
      $env:CASTLE_ENGINE_PATH = $previousEnginePath
      $env:PATH = $previousPath
    }

    $distRoot = Join-Path $BuildDirectory 'castle-engine-output/web/dist'
    Copy-Item -LiteralPath 'tests/webgl-transfer/probe.html' -Destination $distRoot
    $wasmPath = Join-Path $distRoot 'transferprobe.wasm'
    $engineSource = Join-Path $resolvedEnginePath `
      'src/base_rendering/web/castleinternalwebgl.pas'
    $engineSourceHash = (Get-FileHash -LiteralPath $engineSource -Algorithm SHA256).Hash.ToLowerInvariant()
    $wasmHash = (Get-FileHash -LiteralPath $wasmPath -Algorithm SHA256).Hash.ToLowerInvariant()

    $serverPath = & (Join-Path $repositoryRoot 'tools/serve.ps1') `
      -BuildOnly -NativeCompiler $NativeCompiler |
      Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) {
      throw 'The Pascal probe server did not compile.'
    }
    $serverOptions = @{
      FilePath = $serverPath
      ArgumentList = @('--root', $distRoot, '--bind', '127.0.0.1', '--port', "$Port")
      PassThru = $true
      RedirectStandardOutput = (Join-Path $EvidenceDirectory 'server.log')
      RedirectStandardError = (Join-Path $EvidenceDirectory 'server-error.log')
    }
    if ($IsWindows) {
      $serverOptions.WindowStyle = 'Hidden'
    }
    $serverProcess = Start-Process @serverOptions
    $serverReady = $false
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
      try {
        $connection = [Net.Sockets.TcpClient]::new('127.0.0.1', $Port)
        $connection.Dispose()
        $serverReady = $true
        break
      } catch {
        Start-Sleep -Milliseconds 100
      }
    }
    if (-not $serverReady) {
      throw "The Pascal probe server did not listen on port $Port."
    }
    $TestUrl = "http://127.0.0.1:$Port/probe.html"
  }

  $driverArguments = @($Browser, $TestUrl, $EvidenceDirectory)
  if ($RequireSignedRangeGuard) {
    $driverArguments += 'require-signed-range-guard'
  }
  & (Join-Path $binaryRoot $testName) @driverArguments
  if ($LASTEXITCODE -ne 0) { throw "WebGL transfer checks failed. Evidence: $EvidenceDirectory" }

  $metadata = [ordered]@{
    testUrl = $TestUrl
    signedRangeGuardRequired = [Boolean]$RequireSignedRangeGuard
    engineSourceSha256 = $engineSourceHash
    wasmSha256 = $wasmHash
    transferTestSha256 = (Get-FileHash -LiteralPath `
      'tests/webgl-transfer/code/phanes.tests.webgl.transfer.pas' -Algorithm SHA256).Hash.ToLowerInvariant()
    browserDriverSha256 = (Get-FileHash -LiteralPath `
      'tests/phanes.tests.webgl.transfer.browser.lpr' -Algorithm SHA256).Hash.ToLowerInvariant()
    wrapperSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    generationArguments = $generationArguments
    buildArguments = $buildArguments
    webToolchainDirectory = $resolvedWebToolchain
  }
  $metadata | ConvertTo-Json -Depth 3 |
    Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'verification.json') -Encoding utf8
} finally {
  if ($serverProcess -and -not $serverProcess.HasExited) {
    Stop-Process -Id $serverProcess.Id
    $serverProcess.WaitForExit()
  }
  Pop-Location
}
