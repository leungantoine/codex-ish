# OpenAI Codex CLI for iSH-AOK (ARM64 Alpine)

This repository builds **OpenAI's real Codex CLI** for the ARM64 Alpine guest in [iSH-AOK](https://github.com/emkey1/ish-AOK). It pins OpenAI Codex [`rust-v0.158.0`](https://github.com/openai/codex/tree/rust-v0.158.0), commit `064c6b8c737f5b41d171fdda80bd9ef10ad06eb3`, and applies two small Linux subprocess compatibility changes. The target is `aarch64-unknown-linux-musl`.

**Device status:** the shell-command crash was reported on an **iPhone 13 Pro running iSH-AOK build 556**, using Alpine 3.23.3 ARM64. The published binary is **not yet confirmed working on the device**. The updated launcher supplies `--no-daemon` and disables the code-mode host, whose V8 execution fails in the matching iSH emulator. Ordinary shell execution passes in that emulator; the launcher change still needs an iPhone retest.

**Build status:** real binaries were compiled successfully in [build run 36677875179](https://github.com/leungantoine/codex-ish/actions/runs/36677875179). The license-complete [Release `ish-v0.158.0-3.1`](https://github.com/leungantoine/codex-ish/releases/tag/ish-v0.158.0-3.1) passed [final verification](https://github.com/leungantoine/codex-ish/actions/runs/36732272923). Download the [latest Release](https://github.com/leungantoine/codex-ish/releases/latest), containing `codex-ish-aarch64.tar.gz` and `codex-ish-aarch64.tar.gz.sha256`. Authentication and shell execution on iOS still require the device test below.

## Install directly in iSH-AOK

Allow at least 1 GB free for a fresh installation, or 2 GB when retaining the previous installation during an update. The archive is about 203 MiB compressed and its executables total about 638 MiB.

Select iSH-AOK's **ARM64 Alpine** root and verify `uname -m` reports `aarch64`. The regular x86 iSH root cannot run this binary. In iSH:

```sh
uname -m
apk add ca-certificates curl tar coreutils git bash
update-ca-certificates
curl -fL https://raw.githubusercontent.com/leungantoine/codex-ish/main/install.sh -o install-codex-ish.sh
sh install-codex-ish.sh
export PATH="$HOME/.local/bin:$PATH"
codex --version
```

The installer downloads `codex-ish-aarch64.tar.gz` and its `.sha256` file from the repository's latest Release, verifies the archive and internal checksums, extracts all companion executables to `~/.local/opt/codex-ish`, creates a `~/.local/bin/codex` launcher that supplies `--no-daemon --disable code_mode_host`, and links `~/.local/bin/rg`. It rejects other architectures. The archive includes a static ARM64 musl `rg` in `codex-path/`, matching OpenAI's package layout. Inspect `install.sh` before running it if you wish. Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.profile` for future sessions (and to `~/.bashrc` if you use interactive bash without a login shell). If no Release exists or a download/checksum fails, installation stops.

### Update an existing installation without downloading the archive again

```sh
curl -fL https://raw.githubusercontent.com/leungantoine/codex-ish/main/install.sh -o install-codex-ish.sh
sh install-codex-ish.sh --launcher-only
export PATH="$HOME/.local/bin:$PATH"
codex --version
```

This updates only the launcher and requires an installed executable. The compiled Release binaries and their checksums remain unchanged. The code-mode host is still packaged, but the launcher disables it to avoid the reproduced V8 failure. Direct shell tools remain available. Models requiring code-mode-only tools may reject this configuration. `CODEX_ISH_USE_CODE_MODE_HOST=1` opts into the unsupported host for investigation; invoking the installed binary directly also bypasses the launcher defaults.

You can also download the two Release assets yourself, run `sha256sum -c codex-ish-aarch64.tar.gz.sha256`, and extract the archive into `~/.local/opt/codex-ish`. Keep `codex-code-mode-host` and `codex-responses-api-proxy` beside `codex`; do not copy only the CLI executable.

## Sign in and test a shell command

```sh
codex login --device-auth
mkdir -p "$HOME/codex-test"
cd "$HOME/codex-test"
codex --no-daemon --sandbox danger-full-access --ask-for-approval on-request
```

Ask Codex to run `printf 'ish-shell-ok\n'` with its local shell and show the output. Check that the command exits successfully and displays `ish-shell-ok`. For an unattended smoke test after login:

```sh
codex exec --sandbox danger-full-access --ask-for-approval never \
  --skip-git-repo-check \
  "Use the local shell to run printf 'ish-shell-ok\\n', then report its exact output."
```

The archive's `diagnostics/ish-syscall-probe` prints the actual `PR_SET_PDEATHSIG`, `pidfd_open`, `waitid(P_PIDFD)`, and `waitpid` results in the iPad guest. Run it if subprocesses still fail, and include its output with the Codex error in an issue. It does not use the network or credentials.

### Sandbox and security

iSH-AOK does not provide the Linux kernel facilities used by Codex's normal Linux sandbox. This package does not ship `bwrap`. `--sandbox danger-full-access` gives Codex-run commands access to the files and network available inside that iSH guest. Keep sensitive data out of the guest, review shell actions before approving them, and use `--ask-for-approval never` only for the short unattended smoke test. Your ChatGPT/OpenAI login happens on the iPad after installation; the build and archive contain no authentication tokens.

## What is patched

| Location | iSH behavior | Narrow fallback | Normal Linux behavior |
| --- | --- | --- | --- |
| `codex-rs/utils/pty/src/process_group.rs` | `prctl(PR_SET_PDEATHSIG, SIGTERM)` can return `EINVAL` in child setup. | Treat that one error as unsupported and skip the parent-PID race guard, since no death signal was armed. Other errors remain fatal. | Arm `SIGTERM` and retain the parent-PID guard. |
| `codex-rs/vendor/tokio-1.52.3/src/process/unix/pidfd_reaper.rs` | `pidfd_open` can succeed while `waitid(P_PIDFD)` returns `EINVAL` ([reported issue](https://github.com/openai/codex/issues/40454)). | Probe with `WEXITED | WNOHANG | WNOWAIT`; on `EINVAL`, close the fd and use Tokio's existing SIGCHLD child reaper. `WNOWAIT` does not consume an exited child's status. | Keep Tokio's pidfd reaper. |

The patched Tokio is selected with `[patch.crates-io]` in `codex-rs/Cargo.toml` and recorded in `Cargo.lock`. This is a local vendor of the upstream Tokio 1.52.3 crate, not a replacement Codex implementation. `ish-overlay.tar.gz` contains these exact source edits plus the build script. It is applied to the pinned OpenAI source during CI.

## Build and verification

The [workflow](.github/workflows/build.yml) runs on Ubuntu 24.04 x86_64. It clones the pinned OpenAI release and checks its commit before applying `ish-overlay.tar.gz`. Rust 1.95.0 builds the `aarch64-unknown-linux-musl` target; Zig 0.14.0 supplies the C/C++ cross compiler. The build script checks OpenAI's prebuilt V8 archive against the checksum committed in upstream, builds static musl OpenSSL, then builds `codex`, `codex-code-mode-host`, and `codex-responses-api-proxy`. A low-memory release profile is used. It downloads [ripgrep 15.2.0's official ARM64 musl asset](https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0), checks its published SHA-256 digest, and packages `rg` and its licenses. The archive includes OpenAI’s Apache 2.0 `LICENSE` and `NOTICE`. It also contains an empty `codex-resources/` directory for the usual package layout, diagnostics, build information, and SHA-256 sums. This iSH build omits `bwrap` because its sandbox cannot run in iSH.

CI checks that each executable, including bundled `rg` and the diagnostic probe, is AArch64 ELF with no program interpreter or shared-library `NEEDED` entry. It verifies internal package checksums, runs `codex --version`, `rg --version`, and the syscall probe under `qemu-aarch64-static`, and publishes the archive and checksum both as an Actions artifact and a GitHub Release. The Release tag includes the Actions run number, so older builds remain available. `releases/latest` points to the newest successful published build.

### Recorded verification

- The published archive was downloaded independently and its outer checksum and every internal executable checksum were verified.
- All five executables are ELF64 AArch64 with no `PT_INTERP` or shared-library `DT_NEEDED` dependencies.
- Under QEMU: `codex-cli 0.158.0`, both companion executables’ help, the device-auth CLI option, ripgrep searching a sample file, and the diagnostic fork/wait probe passed.
- [The subprocess verification workflow](.github/workflows/verify-release.yml) compiles the exact patched PTY module and vendored Tokio into a native Linux harness. All three test modes passed. It checks 20 worker-thread shell spawns, stdout/stderr, exit status 17, and child termination/reaping. A test-only syscall shim exercises `prctl`/`waitid(P_PIDFD)` returning `EINVAL`, verifies the parent guard is skipped, and checks that `EPERM` remains fatal. The shim is never included in the Release.
- [Emulator run 36787134523](https://github.com/leungantoine/codex-ish/actions/runs/36787134523) built iSH-AOK Release 556 (`19b129bed782897a94d56e1855497f831cfdd405`) on an ARM64 Linux host and ran Alpine 3.23.3 through its guest kernel and ARM64 JIT. The downloaded, unchanged Release binary passed actual `command/exec` pipe and PTY shell calls, output capture and exit status 17. Worker-thread fork, posix_spawn, and the actual Codex setup-helper handshake also passed. The updated installer and embedded-mode launcher passed on native ARM64 Linux. This test uses guest `/bin/sh`; native iSH-AOK shell applets, the interactive TUI/model flow, device authentication, and iOS memory limits were not exercised.
- [Launcher verification run 36811040124](https://github.com/leungantoine/codex-ish/actions/runs/36811040124) tested the full installer and `--launcher-only` update, confirmed `code_mode_host` is disabled, and passed native ARM64 and iSH build 556 pipe/PTY shell calls with the compatibility settings. Its optional code-mode comparison reported **`oom-kill`, memory peak 2.0 GiB**, during actual V8 execution in both iSH cases, with and without OpenSSL CPU probes. Native Linux JavaScript execution passed. The overall workflow's success covers the launcher/shell checks; it does not mean the optional code-mode host passed.
- The original binaries are from Release `ish-v0.158.0-3`; the license-complete package `ish-v0.158.0-3.1` preserves those executable hashes. See [the verification run](https://github.com/leungantoine/codex-ish/actions/runs/36732272923) for the test results and publication.

These native harness tests exercise the patched source on Linux. They do not exercise the static ARM64 binary under iSH’s syscall implementation.

### Diagnose the reported device crash

A subsequent device test reached the interactive UI and received a model response, but `gpt-6-luna` refused the shell call because the code-mode host was disabled. Its displayed `ish-shell-ok` was **predicted output, not an executed command**. The pinned upstream catalog marks the GPT-6 and GPT-5.6 models as `code_mode_only`, which overrides feature flags. It marks `gpt-5.5` with no required code-mode override. Start a **new session with `--model gpt-5.5 --disable code_mode --disable code_mode_only`** for the direct-shell device test; do not resume the failing GPT-6 session. Backend availability and successful device execution with this model still need verification.

The device diagnostics recorded an ARM64 illegal instruction `0xd53b2400` at `0x4978184` in `codex-code-mode-host`. The published binary's ELF symbol table identifies that address as OpenSSL's `_armv8_rng_probe` (RNDR); the return address is in `arm_probe_for`. iSH records this event before delivering SIGILL, including signals caught by an application. OpenSSL catches unsupported CPU-feature probes, so the event alone does not establish the native app's crash cause.

[Code-mode reproduction run 36811040124](https://github.com/leungantoine/codex-ish/actions/runs/36811040124) completed a real host handshake and JavaScript execution on native ARM64 Linux. The same published host passed its handshake but failed during JavaScript execution under iSH build 556, both with normal CPU probing and with `OPENSSL_armcap=0` set **inside the guest**. Both emulator services reached the **2.0 GiB host memory limit** and reported **`oom-kill`** in about one second. The comparison retained logs. This establishes an emulator memory failure; attributing the iPhone app's closure to the same failure remains an inference until its native crash report or successful workaround test is available. Ordinary Codex pipe/PTY shell execution continued to pass. This reproduces an additional runtime failure absent from the earlier shell tests; the native iOS crash report is still needed to confirm the device's cause.

For an immediate comparison using the existing binary:

```sh
codex --no-daemon --disable code_mode_host \\
  --sandbox danger-full-access --ask-for-approval on-request
```

Ask it to execute `printf 'ish-shell-ok\\n'`. The updated installer supplies the first two flags automatically. This is a compatibility workaround with emulator verification; it is **not yet confirmed on the iPhone**. If it still closes, reopen iSH-AOK, select **Support → Diagnostics → Share**, and attach the export, including the crash-time JSON in its `MetricKitDiagnostics` subfolder. Preserve the exact crash time, iSH build number, `codex --version`, and diagnostic probe output. A `JetsamEvent` should name the main `iSH-AOK` process with a termination reason before attributing its closure to memory pressure; a FileProvider-only termination does not establish that. Keep authentication files and tokens private.

If further isolation is needed, the previous diagnostic comparison also disables `shell_snapshot` and `unified_exec`, selecting the legacy shell path. These extra flags are not part of the default launcher.

**Verification limit:** QEMU runs ordinary Linux syscalls, not iSH-AOK's implementation. CI cannot prove that login or child shell commands work on your iPad. The final `printf` test above must be run inside iSH-AOK. A failure there should be reported with the diagnostic probe output, iSH-AOK version, and `codex --version`.

## Rebuild and update the pinned Codex release

1. Inspect the latest stable `rust-v…` tag in `openai/codex`, especially `utils/pty/src/process_group.rs`, Tokio's selected version, its Unix reaper, the CLI binary list, and upstream release packaging. Check whether either compatibility fix has landed upstream. Do not reapply the old code blindly.
2. Start from that exact upstream tag and commit. Reapply only the compatibility changes still necessary. If Tokio has changed, vendor the matching locked version and update its pidfd fallback; update `Cargo.toml` and `Cargo.lock` together. If upstream provides a correct fallback, remove the local vendor override.
3. Recreate `ish-overlay.tar.gz` with the changed `Cargo.toml`, `Cargo.lock`, patched PTY file, vendored Tokio directory (if needed), wrappers, build script, diagnostic source, and bundled READMEs. The current overlay's member list can be inspected with `tar -tzf ish-overlay.tar.gz`. Keep it limited to changed/build files; CI fetches the rest from OpenAI.
4. Update the tag and commit check in `.github/workflows/build.yml`, and the `STABLE_GIT_COMMIT`, V8 manifest handling, and package version in `scripts/build-ish-aarch64.sh` inside the overlay. Revisit Rust/Zig versions and the list of companion executables for that release. The V8 download must continue to match its upstream committed checksum.
5. Push the overlay and workflow, or run **Actions → Build Codex for iSH-AOK → Run workflow**. Inspect the build log, architecture/linkage checks, QEMU version result, package contents, and Release checksum. Finally test shell execution and login in iSH-AOK. Do not label a release working on iSH until that device test succeeds.

The build uses one Cargo job, release LTO off, debug information 0, optimization level 2 and 16 codegen units, with codegen units 1 for `zbus` and `codex-model-provider`. `-C link-self-contained=no` lets Zig supply musl startup objects, avoiding duplicate `_start` symbols from Rust’s bundled objects. CI first tests this linker setup with a tiny static ARM64 program. OpenSSL settings loaded from `GITHUB_ENV` are exported using `set -a` while sourcing them. Hosted runners remove unused SDKs and allocate swap only when sufficient disk remains; retain both memory and disk headroom when changing the profile.

The source overlay can be reproduced on an Ubuntu 24.04 builder with Rust 1.95.0, its ARM64 musl target, Zig 0.14.0, Perl, make, CMake, pkg-config, and Clang: clone the pinned Codex tag, extract `ish-overlay.tar.gz` at its root, then run `./scripts/build-ish-aarch64.sh`. This is a maintenance path for builders; **the iPad installation uses the finished Release binary**.

### Common failures

- **Startup requires `--no-daemon`:** use that flag for interactive sessions, including `resume` and `fork`. The updated installer supplies `--no-daemon` automatically; use `sh install-codex-ish.sh --launcher-only` to update the launcher. Invoking `~/.local/opt/codex-ish/codex` directly bypasses it. `CODEX_ISH_USE_DAEMON=1` explicitly opts into the unsupported daemon path.
- **The entire iSH-AOK app closes on a shell command:** this is a reported unresolved failure. After reopening the app, run the diagnostic probe. Record the iSH-AOK build number and the matching iOS Analytics `iSH-AOK` crash or `JetsamEvent` report; these distinguish a native emulator crash from an OS memory-pressure termination.

- **`uname -m` says `i686` or `x86_64`:** switch to iSH-AOK's ARM64 Alpine root.
- **TLS or download failure:** install/update `ca-certificates` and check connectivity to GitHub Releases. A missing Release means CI has not finished successfully.
- **`codex: not found` after installation:** export `PATH="$HOME/.local/bin:$PATH"` or invoke `~/.local/opt/codex-ish/codex` directly.
- **`Exec format error`:** wrong guest architecture or an incomplete download; check `uname -m` and the SHA-256 result.
- **Login needs a browser:** use `codex login --device-auth` and finish the device flow on another browser/device.
- **Child shell exits immediately:** run `~/.local/opt/codex-ish/diagnostics/ish-syscall-probe`, confirm the `danger-full-access` flag, and file an issue with its output and the iSH-AOK version.
- **CI archive mapping error:** the workflow retries that specific intermittent Rust archive error from the incremental cache. A persistent compiler error needs source/build changes; inspect the failed job logs rather than publishing an unverified artifact.

This project is a compatibility build from [OpenAI's Codex source](https://github.com/openai/codex), not an official OpenAI distribution. iSH-AOK is maintained separately by [emkey1](https://github.com/emkey1/ish-AOK).
