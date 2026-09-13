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
  [string]$CastleTool = $env:CASTLE_TOOL,
  [ValidateSet('debug', 'release')][string]$Mode = 'release',
  [switch]$WithTests,
  [switch]$SkipCatalogPackaging,
  [string]$NativeCompiler = $(if ($env:FPC_NATIVE) { $env:FPC_NATIVE } else { 'fpc' }),
  [string]$Compiler = $(if ($env:PAS2JS) {
      $env:PAS2JS
    } else {
      'pas2js'
    }),
  [string]$RtlRoot = $env:PAS2JS_RTL,
  [string]$RuntimeJs = $(if ($env:PAS2JS_RUNTIME) {
      $env:PAS2JS_RUNTIME
    } else {
      'rtl.js'
    }),
  [string[]]$CompilerOptions = @()
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$outputDirectory = Join-Path $repositoryRoot 'build/web'
foreach ($dependency in @('vendor/wfc/src/wfc.pas', 'vendor/castle-engine/src')) {
  if (-not (Test-Path (Join-Path $repositoryRoot $dependency))) {
    throw 'Initialize dependencies: git submodule update --init --recursive'
  }
}

if (-not $CastleTool) {
  $toolName = if ($IsWindows) {
    'castle-engine.exe'
  } else {
    'castle-engine'
  }
  $CastleTool = Join-Path $repositoryRoot "vendor/castle-engine/tools/build-tool/$toolName"
}
if (-not (Get-Command $CastleTool -ErrorAction SilentlyContinue)) {
  throw 'Build the pinned Castle command line tool, or set CASTLE_TOOL to its executable.'
}

New-Item -ItemType Directory -Force -Path $outputDirectory, "$repositoryRoot/build/units" | Out-Null
$previousEnginePath = $env:CASTLE_ENGINE_PATH
try {
  $env:CASTLE_ENGINE_PATH = Join-Path $repositoryRoot 'vendor/castle-engine'
  & $CastleTool "--project=$repositoryRoot/cge" generate-program
  if ($LASTEXITCODE -ne 0) {
    throw 'Castle project generation failed'
  }
  # Rebuild authored units together: a changed record returned through another
  # unit can otherwise leave a stale WASM caller with an incompatible temporary.
  $projectUnitCache = Join-Path $repositoryRoot 'cge/castle-engine-output/compilation/wasm32-wasip1'
  if (Test-Path -LiteralPath $projectUnitCache) {
    Get-ChildItem -LiteralPath $projectUnitCache -File -Filter 'phanes.*' |
      Where-Object { $_.Extension -in '.o', '.ppu' } |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName }
  }
  & $CastleTool "--project=$repositoryRoot/cge" '--target=web' "--mode=$Mode" compile
  if ($LASTEXITCODE -ne 0) {
    throw 'Castle web build failed. Use a 64-bit-host FPC WASM compiler with matching RTL.'
  }
} finally {
  $env:CASTLE_ENGINE_PATH = $previousEnginePath
}

Copy-Item "$repositoryRoot/cge/castle-engine-output/web/dist/*" $outputDirectory -Recurse -Force
& (Join-Path $repositoryRoot 'tools/build-host.ps1') -Compiler $Compiler -RuntimeJs $RuntimeJs `
  -RtlRoot $RtlRoot -CompilerOptions $CompilerOptions -NativeCompiler $NativeCompiler
Copy-Item "$repositoryRoot/web/*" $outputDirectory -Recurse -Force
New-Item -ItemType Directory -Force "$outputDirectory/data" | Out-Null
Copy-Item "$repositoryRoot/data/*.json" "$outputDirectory/data" -Force
New-Item -ItemType Directory -Force "$outputDirectory/data/music" | Out-Null
Copy-Item "$repositoryRoot/data/music/*.json" "$outputDirectory/data/music" -Force

$workerArguments = @('-B', '-Tbrowser', '-Mdelphi', '-Jc', "-Ji$RuntimeJs")
$workerArguments += @("-Fu$repositoryRoot/vendor/wfc/src", "-Fu$repositoryRoot/src")
$workerArguments += @("-FU$repositoryRoot/build/units", "-FE$outputDirectory")
if ($RtlRoot) {
  $workerArguments += "-Fu$RtlRoot/packages/rtl/src"
}
$workerArguments += "$repositoryRoot/src/phanes.worker.lpr"
& $Compiler @CompilerOptions @workerArguments
if ($LASTEXITCODE -ne 0) {
  throw 'World worker compilation failed'
}

foreach ($entry in @('phanes.music.worker', 'phanes.audio.browser', 'phanes.interiors.browser')) {
  $audioArguments = $workerArguments[0..($workerArguments.Count - 2)] +
    "$repositoryRoot/src/$entry.lpr"
  & $Compiler @CompilerOptions @audioArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Pascal audio compilation failed: $entry"
  }
  # Each compiled Pascal program has its own RTL/module registry. Isolate that
  # generated registry from Castle's host and start its Pascal entry point.
  $audioPath = Join-Path $outputDirectory "$entry.js"
  $audioCode = [IO.File]::ReadAllText($audioPath)
  [IO.File]::WriteAllText($audioPath, "(() => {`n$audioCode`nrtl.run();`n})();`n")
}

if ($WithTests) {
  $arguments = @('-B', '-Tbrowser', '-Mdelphi', '-Jc', "-Ji$RuntimeJs")
  $arguments += @("-Fu$repositoryRoot/vendor/wfc/src", "-Fu$repositoryRoot/tests")
  $arguments += @("-FU$repositoryRoot/build/units", "-FE$repositoryRoot/build")
  if ($RtlRoot) {
    $arguments += "-Fu$RtlRoot/packages/rtl/src"
  }
  $arguments += "$repositoryRoot/tests/phanes.tests.lpr"
  & $Compiler @CompilerOptions @arguments
  if ($LASTEXITCODE -ne 0) {
    throw 'pas2js dependency smoke compilation failed'
  }
  $audioTestArguments = $arguments[0..($arguments.Count - 2)] +
    "$repositoryRoot/tests/phanes.tests.audio.lpr"
  & $Compiler @CompilerOptions @audioTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal audio browser checks failed to compile'
  }
  $selectionTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "$repositoryRoot/tests/phanes.tests.selection.lpr"
  & $Compiler @CompilerOptions @selectionTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal selection and preservation checks failed to compile'
  }
  $compositionTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "-Fu$repositoryRoot/tests" +
    "$repositoryRoot/tests/phanes.tests.composition.lpr"
  & $Compiler @CompilerOptions @compositionTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal composition document checks failed to compile'
  }
  $groundworkTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "-Fu$repositoryRoot/tests" +
    "$repositoryRoot/tests/phanes.tests.groundworks.lpr"
  & $Compiler @CompilerOptions @groundworkTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal groundwork domain checks failed to compile'
  }
  $floorTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "-Fu$repositoryRoot/tests" +
    "$repositoryRoot/tests/phanes.tests.floor.lpr"
  & $Compiler @CompilerOptions @floorTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal room floor placement checks failed to compile'
  }
  $spacesTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "-Fu$repositoryRoot/tests" +
    "$repositoryRoot/tests/phanes.tests.spaces.lpr"
  & $Compiler @CompilerOptions @spacesTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal named-room composition checks failed to compile'
  }
  $spaceIntegrationArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "-Fu$repositoryRoot/tests" +
    "$repositoryRoot/tests/phanes.tests.spaces.integration.lpr"
  & $Compiler @CompilerOptions @spaceIntegrationArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal room world and wall checks failed to compile'
  }
  $terrainTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "-Fu$repositoryRoot/tests" +
    "$repositoryRoot/tests/phanes.tests.terrain.lpr"
  & $Compiler @CompilerOptions @terrainTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal terrain height field checks failed to compile'
  }
  $landformTestArguments = $arguments[0..($arguments.Count - 2)] +
    "-Fu$repositoryRoot/src" + "$repositoryRoot/tests/phanes.tests.landforms.lpr"
  & $Compiler @CompilerOptions @landformTestArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Pascal world landform integration checks failed to compile'
  }
}

if (-not $SkipCatalogPackaging) {
  & (Join-Path $repositoryRoot 'tools/assets.ps1') -Action package-catalog -NativeCompiler $NativeCompiler
}
Write-Output "Web build: $outputDirectory"
