#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
export PATH="${ZIG_DIR:-/opt/zig}:$HOME/.cargo/bin:$PATH"
export TARGET=aarch64-unknown-linux-musl
export CC="$repo_root/build-tools/zigcc" CXX="$repo_root/build-tools/zigcxx"
export TARGET_CC="$CC" TARGET_CXX="$CXX"
export CC_aarch64_unknown_linux_musl="$CC" CXX_aarch64_unknown_linux_musl="$CXX"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER="$CC"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="${CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUSTFLAGS:-} -C link-self-contained=no"
export CMAKE_C_COMPILER="$CC" CMAKE_CXX_COMPILER="$CXX"
export CFLAGS='-pthread -Wno-error=frame-larger-than' CXXFLAGS='-pthread -Wno-error=frame-larger-than'
export AWS_LC_SYS_NO_JITTER_ENTROPY=1 AWS_LC_SYS_NO_JITTER_ENTROPY_aarch64_unknown_linux_musl=1
export PKG_CONFIG_ALLOW_CROSS=1 STABLE_GIT_COMMIT="01fc69f4026735edfdf6789820549727a4867b11"
export RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
export GITHUB_ENV="$(mktemp)"
trap 'rm -f "$GITHUB_ENV"' EXIT
# Lower memory profile for the large Codex core/TUI crates on an 8 GB builder.
export CARGO_PROFILE_RELEASE_DEBUG=0 CARGO_PROFILE_RELEASE_LTO=off
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 CARGO_PROFILE_RELEASE_OPT_LEVEL=2
v8_version="$(python3 .github/scripts/rusty_v8_bazel.py resolved-v8-crate-version)"
v8_dir="$RUNNER_TEMP/ish-rusty-v8"; mkdir -p "$v8_dir"
prefix="ptrcomp_sandbox_release_${TARGET}"
manifest="rusty_v8_${prefix}.sha256"
archive="librusty_v8_${prefix}.a.gz"
binding="src_binding_${prefix}.rs"
base="https://github.com/openai/codex/releases/download/rusty-v8-v${v8_version}"
for item in "$manifest" "$archive" "$binding"; do
  if [[ ! -s "$v8_dir/$item" ]]; then curl -fsSL "$base/$item" -o "$v8_dir/$item"; fi
done
trusted="third_party/v8/rusty_v8_${v8_version//./_}_release_manifests.sha256"
expected="$(awk -v n="$manifest" '$2 == n {print $1}' "$trusted")"
actual="$(sha256sum "$v8_dir/$manifest" | awk '{print $1}')"
[[ -n "$expected" && "$expected" == "$actual" ]]
(cd "$v8_dir" && tr -d '\r' < "$manifest" | sha256sum -c -)
export RUSTY_V8_ARCHIVE="$v8_dir/$archive" RUSTY_V8_SRC_BINDING_PATH="$v8_dir/$binding"
OPENSSL_CC="$CC" OPENSSL_BUILD_JOBS="${OPENSSL_BUILD_JOBS:-2}" bash .github/scripts/install-musl-openssl.sh
set -a
source "$GITHUB_ENV"
set +a
cd codex-rs
cargo build --locked --release --target "$TARGET" -j "${CARGO_BUILD_JOBS:-1}" \
  --bin codex --bin codex-code-mode-host --bin codex-responses-api-proxy
cd "$repo_root"
package="$repo_root/dist/codex-ish-aarch64"
mkdir -p "$package/codex-resources" "$package/codex-path" "$package/diagnostics" "$package/licenses/ripgrep" "$package/compat"
for name in codex codex-code-mode-host codex-responses-api-proxy; do
  install -m 0755 "codex-rs/target/$TARGET/release/$name" "$package/$name"
done
# OpenAI's release layout includes rg. Use the matching upstream ripgrep
# AArch64 musl asset, pinned to its publisher-provided SHA-256 digest.
rg_version=15.2.0
rg_name="ripgrep-${rg_version}-aarch64-unknown-linux-musl"
rg_archive="$RUNNER_TEMP/${rg_name}.tar.gz"
curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${rg_version}/${rg_name}.tar.gz" -o "$rg_archive"
echo "800b1e7206afe799dfb5a6901f23147cfaabe0e52210538100f61e86e1740915  $rg_archive" | sha256sum -c -
tar -xOzf "$rg_archive" "$rg_name/rg" > "$package/codex-path/rg"
chmod 0755 "$package/codex-path/rg"
for license in COPYING LICENSE-MIT UNLICENSE; do
  tar -xOzf "$rg_archive" "$rg_name/$license" > "$package/licenses/ripgrep/$license"
done
"$CC" -O2 -static tests/ish-syscall-probe.c -o "$package/diagnostics/ish-syscall-probe"
cp tests/ish-syscall-probe.c "$package/diagnostics/ish-syscall-probe.c"
cat > "$package/BUILDINFO.txt" <<INFO
OpenAI Codex rust-v0.159.3
Upstream commit: $STABLE_GIT_COMMIT
Target: $TARGET
Rust: $(rustc --version)
Patched source: codex-rs/utils/pty/src/process_group.rs, codex-rs/vendor/tokio-1.52.3/src/process/unix/pidfd_reaper.rs
Bundled ripgrep: 15.2.0 aarch64-unknown-linux-musl (official release SHA-256 pinned in build script)
The Linux bubblewrap sandbox is unavailable in iSH-AOK and is not bundled.
GPT-6 direct-tool catalog and codex-gpt6 launcher are included; daemon and V8 hosting stay disabled.
INFO
cp "$package/BUILDINFO.txt" "$package/BUILDINFO"
cp ish-compat/models-direct.json ish-compat/PATCHINFO.json "$package/compat/"
install -m 0755 scripts/codex-gpt6 "$package/codex-gpt6"
cp README-ish.md "$package/README.md"
cp LICENSE NOTICE "$package/"
(cd "$package" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar -C "$package" -czf "$repo_root/dist/codex-ish-aarch64.tar.gz" .
sha256sum "$repo_root/dist/codex-ish-aarch64.tar.gz"
