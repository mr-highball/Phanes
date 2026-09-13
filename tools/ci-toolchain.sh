#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2026 mr-highball
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Ubuntu 24.04, x86_64 host; build only the browser game's compiler tools.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
toolchain="$repo/build/ci-toolchain"
prefix="$toolchain/fpc"
source_dir="$toolchain/source"
pas2js_dir="$toolchain/pas2js"
fpc_revision=d7f522a5611b13f37164c5eac87ade49b2f5b324
pas2js_revision=fa10c59214cd226c60af465c831d66a7321f0214
mkdir -p "$toolchain" "$repo/build/logs"

checkout() {
  local url=$1
  local revision=$2
  local destination=$3
  if [[ ! -d "$destination/.git" ]]; then
    git init "$destination"
  fi
  git -C "$destination" fetch --depth 1 "$url" "$revision"
  git -C "$destination" checkout --detach FETCH_HEAD
  test "$(git -C "$destination" rev-parse HEAD)" = "$revision"
}

if [[ ! -f "$toolchain/ready" ]]; then
  checkout https://gitlab.com/freepascal.org/fpc/source.git "$fpc_revision" "$source_dir"
  checkout https://gitlab.com/freepascal.org/fpc/pas2js.git "$pas2js_revision" "$pas2js_dir"
  # The distribution compiler bootstraps trunk; trunk supplies matching native
  # units plus the wasm32-wasip1 compiler/RTL. Keep all installs under build/.
  make -C "$source_dir" -j2 all PP=/usr/bin/ppcx64 NOGDB=1 OPT=-O2 > "$repo/build/logs/fpc-native.log" 2>&1
  make -C "$source_dir" install INSTALL_PREFIX="$prefix" > "$repo/build/logs/fpc-install.log" 2>&1
  ln -sf "$prefix/lib/fpc/3.3.1/ppcx64" "$prefix/bin/ppcx64"
  cat > "$prefix/bin/fpc.cfg" <<EOF
-Fu$prefix/lib/fpc/3.3.1/units/\$fpctarget/*
-Fl$(dirname "$(gcc -print-libgcc-file-name)")
EOF
  export PATH="$prefix/bin:$PATH"
  export PPC_CONFIG_PATH="$prefix/bin"
  make -C "$source_dir" -j2 crossall CPU_TARGET=wasm32 OS_TARGET=wasip1 FPC="$prefix/bin/fpc" NOGDB=1 OPT=-O2 > "$repo/build/logs/fpc-wasm.log" 2>&1
  make -C "$source_dir" crossinstall CPU_TARGET=wasm32 OS_TARGET=wasip1 INSTALL_PREFIX="$prefix" > "$repo/build/logs/fpc-wasm-install.log" 2>&1
  ln -sf "$prefix/lib/fpc/3.3.1/ppcrosswasm32" "$prefix/bin/ppcrosswasm32"
  # FPC's native utils build already compiled pas2js from this same source pin.
  # Pair that executable with the separately pinned browser RTL and config.
  mkdir -p "$pas2js_dir/bin/x86_64-linux"
  cp "$prefix/bin/pas2js" "$pas2js_dir/bin/x86_64-linux/pas2js"
  cp "$source_dir/utils/pas2js/dist/rtl.js" "$pas2js_dir/packages/rtl/rtl.js"
  cat > "$pas2js_dir/bin/x86_64-linux/pas2js.cfg" <<'EOF'
-Sc
-Fu$CfgDir/../../packages/*/src
-Fu$CfgDir/../../packages/rtl
-Jc
EOF
  touch "$toolchain/ready"
fi

export PATH="$pas2js_dir/bin/x86_64-linux:$prefix/bin:$PATH"
export PPC_CONFIG_PATH="$prefix/bin"
fpc -iV
fpc -Pwasm32 -Twasip1 -iV
pas2js -iV
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$prefix/bin" "$pas2js_dir/bin/x86_64-linux" >> "$GITHUB_PATH"
  printf 'PPC_CONFIG_PATH=%s\n' "$prefix/bin" >> "$GITHUB_ENV"
  printf 'PAS2JS_RTL=%s\nPAS2JS_RUNTIME=%s\nCASTLE_TOOL=%s\n' "$pas2js_dir" "$pas2js_dir/packages/rtl/rtl.js" "$repo/vendor/castle-engine/tools/build-tool/castle-engine" >> "$GITHUB_ENV"
fi
