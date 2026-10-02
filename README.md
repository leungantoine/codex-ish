# Codex CLI for iSH-AOK

This repository packages OpenAI Codex for the ARM64 Alpine environment provided by [iSH-AOK](https://github.com/emkey1/ish-AOK). It is an unofficial compatibility build; it is not distributed or supported by OpenAI or the iSH-AOK maintainers.

## Current release

The current source pin is Codex 0.160.0, upstream tag [`rust-v0.160.0`](https://github.com/openai/codex/tree/rust-v0.160.0), commit `a956835d020762cb2b570053af06f643a11c0ecc`. The binary build was published as [`ish-v0.160.0-8`](https://github.com/leungantoine/codex-ish/releases/tag/ish-v0.160.0-8) and passed the [ARM64 build and iSH-AOK emulator workflow](https://github.com/leungantoine/codex-ish/actions/runs/36947797945).

Download the [latest release](https://github.com/leungantoine/codex-ish/releases/latest). Documentation refresh releases may use a `.docs-N` suffix; they retain the verified executables and update the bundled documentation. The [latest docs refresh](https://github.com/leungantoine/codex-ish/actions/runs/36970616038) verified that all five executable hashes were unchanged.

The package targets `aarch64-unknown-linux-musl` and contains the Codex CLI, its companion executables, a direct-tool model catalog, a launcher, ripgrep, diagnostics, licenses, build information, and checksums.

## Installation

Use iSH-AOK's **ARM64 Alpine** root. Confirm the architecture first:

```sh
uname -m
```

The output must be `aarch64`. The release archive is approximately 205 MiB; allow about 1 GiB of free guest storage for a fresh install and 2 GiB for an upgrade that retains the previous package during staging. Then run the setup command:

```sh
apk add --no-cache ca-certificates curl tar coreutils git bash && \
  curl -fsSL --retry 3 https://raw.githubusercontent.com/leungantoine/codex-ish/main/setup.sh \
    -o /tmp/setup-codex-ish.sh && \
  sh /tmp/setup-codex-ish.sh && \
  export PATH="$HOME/.local/bin:$PATH"
```

Start Codex with:

```sh
codex
```

The setup script downloads the latest release, verifies the archive and its internal file checksums, installs the package, configures the direct-tool launcher, and adds `~/.local/bin` to existing shell profiles. Repeating the command upgrades the installation. Open a new iSH session after setup to use the saved PATH.

If Codex is not signed in, authenticate from the iSH terminal:

```sh
codex login --device-auth
```

Complete the device authorization in a browser. Authentication files and tokens are not part of the release archive.

### Default configuration

The recommended setup configures `codex` to use Codex's existing direct shell tools. This path does not require an iSH-AOK app update. It uses:

- GPT-6-Luna with medium reasoning effort.
- The local code-mode host and shared daemon disabled.
- `danger-full-access` with approval on request.

This configuration allows commands to read and modify files and access the network available inside the Alpine guest. iSH-AOK does not provide the Linux kernel features required for Codex's normal Linux sandbox, and this package does not include `bwrap`. Review requested actions before approving them. Do not keep sensitive files in the guest while using this configuration.

To select another bundled direct-tool model, pass `--model`, for example:

```sh
codex --model gpt-6-sol
codex --model gpt-6-astra
codex --model gpt-6.1-sol
codex --model gpt-5.6-sol
```

The current catalog includes GPT-6-Luna, GPT-6-Sol, GPT-6-Astra, GPT-6.1-Sol, GPT-5.6-Luna, GPT-5.6-Terra, and GPT-5.6-Sol. For these entries, the compatibility catalog selects direct tools while retaining the model identifiers and other catalog metadata. The [compatibility guide](compat/README.md) describes the catalog, historical fallback instructions, and model-specific verification limits.

## Verification status and limitations

The current 0.160.0 package passed checksum, architecture, static-linking, QEMU, subprocess, and iSH-AOK build 556 emulator checks. The emulator tests exercise the real release binaries with a local mock service; they verify Codex's tool-execution path, not authenticated inference or the service's acceptance of every request. See the [build workflow](.github/workflows/build.yml) and [compatibility guide](compat/README.md) for test details.

Physical-device testing is more limited. A shell smoke test was recorded on an earlier 0.158.0 package using GPT-5.5. An earlier device report also describes the direct-tool setup working on iSH-AOK. Authentication and broader workloads on the current 0.160.0 package have not been recorded.

### Known limitations

- **Unsandboxed guest commands:** `danger-full-access` uses the files and network available inside Alpine. The standard Codex Linux sandbox is unavailable.
- **Code-mode runtime:** The local V8 code-mode host is disabled by the recommended launcher because it failed under the tested iSH-AOK environment. Direct shell tools bypass that host. Models or tasks that require code-mode-only tools may not work.
- **iOS suspension:** A reported iSH-AOK termination occurred while the app was suspended. This package does not fix that app-level issue. Keep iSH-AOK in the foreground during work where possible. If the app closes, collect iSH-AOK diagnostics and note the app build, time, and Codex version.
- **Device coverage:** Emulator and QEMU success do not establish physical-device reliability. Login, individual models, and larger workloads should be tested on the target device.

For subprocess failures, run `~/.local/opt/codex-ish/diagnostics/ish-syscall-probe` and include its output, the iSH-AOK build, and `codex --version` in a report. Do not include authentication files, tokens, or private task content.

## Package and compatibility details

The build contains:

- `codex`, `codex-code-mode-host`, and `codex-responses-api-proxy`.
- A static ARM64 musl `rg` executable and its licenses.
- The direct-tool catalog, `codex-gpt6` launcher, and `compat/PATCHINFO.json` with source and input hashes.
- `diagnostics/ish-syscall-probe`, `BUILDINFO.txt`, OpenAI's `LICENSE` and `NOTICE`, and `SHA256SUMS`.

Two narrow source changes address iSH subprocess behavior:

1. If `prctl(PR_SET_PDEATHSIG, SIGTERM)` returns `EINVAL`, the PTY setup treats that specific result as unsupported. Other errors remain fatal.
2. If `pidfd_open` succeeds but Tokio's `waitid(P_PIDFD)` returns `EINVAL`, the vendored Tokio code closes the descriptor and falls back to its existing SIGCHLD reaper.

The preparation script verifies the pinned source and dependency versions, checks the Tokio archive against the checksum in the upstream lockfile, and applies these changes without replacing upstream manifests. The historical `ish-overlay.tar.gz` belongs to Codex 0.158.0; it is not used to prepare the current release.

See [experimental/README.md](experimental/README.md) for emulator research and patches that are not included in the release.

## Build and maintenance

The single source pin is maintained in [`codex-upstream.json`](codex-upstream.json). It records the upstream tag, version, commit, Tokio version, and libc version.

For pull requests, the metadata workflow validates pin and script syntax, prepares the exact upstream source, runs focused subprocess tests, and refreshes Bazel dependency metadata. The installer workflow checks setup, PATH configuration, and shell execution. These checks do not build or publish the complete Codex release package.

On `main`, the release workflow performs the ARM64 build and emulator verification when the upstream pin advances. It skips a build when the latest release already contains the pinned version and commit. Use workflow dispatch for an intentional rebuild of the same pin, such as after changing a build script. Publication follows successful package and emulator checks.

Documentation changes use a separate workflow. It verifies the existing archive, copies the current README, compatibility guide, and setup script into the package, checks their checksums, and confirms that the five executable hashes are unchanged before publishing a docs refresh.

The release build uses Rust 1.95.0, Zig 0.14.0, and the `aarch64-unknown-linux-musl` target. It builds the Codex executables and static OpenSSL, adds the checksum-pinned ARM64 musl ripgrep release, checks that package executables have no dynamic loader or shared-library dependencies, and runs the package under QEMU and iSH-AOK build 556.

### Rebuild from source

The automated workflow is the recommended build path. For a manual build, use Ubuntu 24.04 with Rust 1.95.0, Zig 0.14.0, Perl, make, CMake, pkg-config, Clang, and the ARM64 musl target.

From the repository root:

```sh
upstream_tag="$(python3 -c 'import json; print(json.load(open("codex-upstream.json"))["upstream_tag"])')"
git clone --depth 1 --branch "$upstream_tag" https://github.com/openai/codex.git upstream
cp codex-upstream.json upstream/
python3 scripts/prepare-ish-source.py upstream
cp -a build-tools upstream/
cp scripts/build-ish-aarch64.sh scripts/codex-gpt6 upstream/scripts/
mkdir -p upstream/tests upstream/ish-docs/compat
cp tests/ish-syscall-probe.c upstream/tests/
cp README.md upstream/README-ish.md
cp compat/README.md upstream/ish-docs/compat/README.md
cp setup.sh upstream/ish-docs/setup.sh
cargo metadata --manifest-path upstream/codex-rs/Cargo.toml --format-version 1 >/dev/null
upstream/scripts/build-ish-aarch64.sh
```

Before updating Codex, review upstream changes to the PTY setup, Tokio's Unix process reaper, model catalog, and packaged binaries. Remove a local compatibility change if upstream has fixed the corresponding issue. Update the pin and related compatibility changes together; do not apply the historical overlay to a newer checkout.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| `uname -m` is not `aarch64` | Select iSH-AOK's ARM64 Alpine root. |
| `codex: command not found` | Open a new shell or run `export PATH="$HOME/.local/bin:$PATH"`. |
| Download or TLS verification fails | Install `ca-certificates`, check network access, and retry. The installer stops if a checksum fails. |
| `Exec format error` | Confirm the ARM64 root and download the release archive again. |
| Login requires a browser | Run `codex login --device-auth` and complete the device flow on another device. |
| A child shell fails or exits | Run the syscall diagnostic probe and include its output and the iSH-AOK build number in a report. |
| iSH-AOK closes or suspends during a task | Reopen the app and collect its Support → Diagnostics export. The suspension issue is unresolved. |

## License and upstream projects

The release includes OpenAI's `LICENSE` and `NOTICE`. The iSH-AOK application is maintained separately by [its upstream project](https://github.com/emkey1/ish-AOK).