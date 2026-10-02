# OpenAI Codex CLI for iSH-AOK (ARM64 Alpine)

This repository builds **OpenAI's real Codex CLI** for the ARM64 Alpine guest in [iSH-AOK](https://github.com/emkey1/ish-AOK). The current build source pins OpenAI Codex [`rust-v0.160.0`](https://github.com/openai/codex/tree/rust-v0.160.0), commit `a956835d020762cb2b570053af06f643a11c0ecc`, and applies two small Linux subprocess compatibility changes. The target is `aarch64-unknown-linux-musl`.

**Device status: the interactive shell smoke test passed on the user's iSH-AOK device.** Codex 0.158.0 with **GPT-5.5, medium reasoning**, the daemon disabled, and code-mode hosting disabled executed `printf 'ish-shell-ok\n'`, displayed `ish-shell-ok`, and returned **exit status 0**. The original crash diagnostics were supplied for an iPhone 13 Pro running iSH-AOK build 556; the successful screenshot did not independently identify the hardware. This verifies that small direct shell command, not unrestricted compatibility with every workload or model. The user subsequently confirmed that the [GPT-6 direct-tool setup](compat/README.md) works on their device. This is a user report, not a recorded test of every model or workload. Physical-device authentication and broader workload testing on the current 0.160.0 package are still pending.

**Current package:** Codex 0.160.0 is published as [Release `ish-v0.160.0-8`](https://github.com/leungantoine/codex-ish/releases/tag/ish-v0.160.0-8). Its build and emulator verification passed in [run 36947797945](https://github.com/leungantoine/codex-ish/actions/runs/36947797945). Device authentication and broader physical-device workloads still need testing.

**Release:** Download the [latest Release](https://github.com/leungantoine/codex-ish/releases/latest), containing `codex-ish-aarch64.tar.gz` and `codex-ish-aarch64.tar.gz.sha256`. The current 0.160.0 source build passed package, emulator, and launcher verification. The older device-tested 0.158.0 package remains available for rollback.

## Install or upgrade with one command (recommended)

Use the **ARM64 Alpine** root in iSH-AOK. Paste this single command:

```sh
apk add --no-cache ca-certificates curl tar coreutils git bash && curl -fsSL --retry 3 https://raw.githubusercontent.com/leungantoine/codex-ish/main/setup.sh -o /tmp/setup-codex-ish.sh && sh /tmp/setup-codex-ish.sh && export PATH="$HOME/.local/bin:$PATH"
```

Then launch with:

```sh
codex
```

The setup downloads the latest published release, verifies archive and internal checksums, installs its executables and matching direct-tool catalog, and saves PATH setup in shell profiles. After reopening iSH you can type `codex` immediately. It defaults to GPT-6-Luna, medium reasoning, direct tools, daemon disabled, and **unsandboxed guest access with approval on request**. Commands can access guest files and network. Authentication and existing configuration are retained; if you are not signed in, run `codex login --device-auth` once. Nothing automatically launches when iSH opens.

Use `codex --model gpt-6-sol` or `codex --model gpt-6-astra` to choose another model. GPT-6.1-Sol is included in the current package and its matching catalog. Repeating the same command upgrades the binary and launcher. [Startup verification run 36903764289](https://github.com/leungantoine/codex-ish/actions/runs/36903764289) installed the real release on native ARM64 Linux, found `codex` from a fresh login shell with a minimal initial PATH, completed a real direct shell roundtrip without an explicit sandbox argument in the test, and confirmed a repeated install did not duplicate the PATH line. [Final 0.159.3 startup verification](https://github.com/leungantoine/codex-ish/actions/runs/36914234977) repeated the complete setup with the new archive, found plain `codex` from a fresh login shell, reported `codex-cli 0.159.3`, and completed its real direct shell loop. Physical iSH startup remains a device check. Keep iSH visible and the device unlocked while tasks run because of the separately reported suspension failure below.

## GPT-6-Luna, Sol, Astra, and GPT-6.1-Sol: install the Codex direct-tool patch

The [compatibility patch](compat/README.md) uses Codex's existing direct shell tools and bypasses the failing local V8 code-mode runtime. It works with the current released binary and does **not** require an iSH-AOK app update. Install the normal Codex release first, then:

```sh
cd "$HOME"
curl -fL --retry 3 https://raw.githubusercontent.com/leungantoine/codex-ish/main/install-direct-tools.sh -o install-direct-tools.sh
sh install-direct-tools.sh
export PATH="$HOME/.local/bin:$PATH"
codex-gpt6 --sandbox danger-full-access --ask-for-approval on-request
```

The separate `codex-gpt6` launcher defaults to GPT-6-Luna and medium reasoning. Use `--model gpt-6-sol` or `--model gpt-6-astra` to select the other tested configurations. It pins a checksum-verified catalog that changes those models' tool-mode preference to direct execution. The binary, model identity, authentication, existing user config, and normal `codex` command are preserved. The current 0.160.0 package bundles its matching catalog and launcher, including GPT-6.1-Sol (`--model gpt-6.1-sol`). The older 0.158.0 fallback catalog does not add GPT-6.1. Upgrading with `install.sh` replaces `codex-gpt6` with the bundled launcher automatically, preserving authentication and user configuration.

Start a new session and ask it to actually execute `printf 'ish-gpt6-shell-ok\\n'` using the shell tool and show the output and exit status. Success requires a real tool execution card and exit status 0, not predicted output. Commands have access to guest files and network in this unsandboxed configuration.

[Run 36888592596](https://github.com/leungantoine/codex-ish/actions/runs/36888592596) verified the actual released ARM64 binary's GPT-6-Luna, Sol, and Astra configurations on native Linux and **unmodified iSH-AOK build 556**. All six cases advertised direct shell schemas, executed a real random-marker command, returned output and exit status 17 to the next request, and exited zero without invoking V8. The response source was a **local mock server**: these tests establish the Codex execution path, not authenticated service acceptance or the real model's tool choice. The user subsequently confirmed that this GPT-6 setup works. The mock tests remain the recorded execution evidence; larger tasks and each individual model on a physical device remain to be tested. [Details, limitations, and rollback](compat/README.md).

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

This is an advanced repair for the base launcher and requires an installed executable. If you used the one-command setup, repeat that setup afterward to restore plain `codex` with its direct-tool and access defaults. The compiled Release binaries and their checksums remain unchanged. The code-mode host is still packaged, but the launcher disables it to avoid the reproduced V8 failure. Direct shell tools remain available. Models requiring code-mode-only tools may reject this configuration. `CODEX_ISH_USE_CODE_MODE_HOST=1` opts into the unsupported host for investigation; invoking the installed binary directly also bypasses the launcher defaults.

You can also download the two Release assets yourself, run `sha256sum -c codex-ish-aarch64.tar.gz.sha256`, and extract the archive into `~/.local/opt/codex-ish`. Keep `codex-code-mode-host` and `codex-responses-api-proxy` beside `codex`; do not copy only the CLI executable.

## Sign in and test a shell command

```sh
codex login --device-auth
mkdir -p "$HOME/codex-test"
cd "$HOME/codex-test"
codex --model gpt-5.5 --disable code_mode --disable code_mode_only \
  -c 'model_reasoning_effort="medium"' \
  --sandbox danger-full-access --ask-for-approval on-request
```

The installer launcher adds `--no-daemon --disable code_mode_host`. Use the displayed GPT-5.5 model and medium reasoning: the backend rejected the inherited `max` reasoning setting for this model. Explicit command-line flags avoid editing or overwriting an existing user configuration.

Ask Codex to **actually execute** `printf 'ish-shell-ok\n'` with its local shell and show the real output and exit status. The user device test passed with output `ish-shell-ok` and exit status `0`. A predicted result without a tool execution is not a passing test.

For an optional unattended smoke test after login (the interactive path above is the device-verified path):

```sh
codex --disable code_mode --disable code_mode_only \
  -c 'model_reasoning_effort="medium"' \
  exec --model gpt-5.5 --sandbox danger-full-access --ask-for-approval never \
  --skip-git-repo-check \
  "Use the local shell to run printf 'ish-shell-ok\\n', then report its exact output and exit status."
```

The archive's `diagnostics/ish-syscall-probe` prints the actual `PR_SET_PDEATHSIG`, `pidfd_open`, `waitid(P_PIDFD)`, and `waitpid` results in the iPad guest. Run it if subprocesses still fail, and include its output with the Codex error in an issue. It does not use the network or credentials.

### Sandbox and security

iSH-AOK does not provide the Linux kernel facilities used by Codex's normal Linux sandbox. This package does not ship `bwrap`. `--sandbox danger-full-access` gives Codex-run commands access to the files and network available inside that iSH guest. Keep sensitive data out of the guest, review shell actions before approving them, and use `--ask-for-approval never` only for the short unattended smoke test. Your ChatGPT/OpenAI login happens on the iPad after installation; the build and archive contain no authentication tokens.

## What is patched

| Location | iSH behavior | Narrow fallback | Normal Linux behavior |
| --- | --- | --- | --- |
| `codex-rs/utils/pty/src/process_group.rs` | `prctl(PR_SET_PDEATHSIG, SIGTERM)` can return `EINVAL` in child setup. | Treat that one error as unsupported and skip the parent-PID race guard, since no death signal was armed. Other errors remain fatal. | Arm `SIGTERM` and retain the parent-PID guard. |
| `codex-rs/vendor/tokio-<pinned-version>/src/process/unix/pidfd_reaper.rs` | `pidfd_open` can succeed while `waitid(P_PIDFD)` returns `EINVAL` ([reported issue](https://github.com/openai/codex/issues/40454)). | Probe with `WEXITED | WNOHANG | WNOWAIT`; on `EINVAL`, close the fd and use Tokio's existing SIGCHLD child reaper. `WNOWAIT` does not consume an exited child's status. | Keep Tokio's pidfd reaper. |

The patched Tokio is selected with `[patch.crates-io]` in `codex-rs/Cargo.toml` and recorded in `Cargo.lock`. The preparation script vendors the version in `codex-upstream.json` after confirming it matches the upstream lockfile; this is not a replacement Codex implementation. For the pinned upstream release, `scripts/prepare-ish-source.py` verifies the tag and commit from `codex-upstream.json`, checks the pinned Tokio and libc versions against the upstream lockfile, applies `patches/process-group.patch`, downloads Tokio against the lockfile checksum, and makes the narrow pidfd and manifest edits. It retains the new upstream workspace and dependency versions. `ish-overlay.tar.gz` is the historical 0.158.0 input and must not be applied to newer versions.

## Build and verification

The [maintenance workflow](.github/workflows/verify-upgrade-inputs.yml) checks the pin and script syntax, prepares the exact upstream source, runs focused subprocess tests, and refreshes Bazel metadata on pull requests. The [release workflow](.github/workflows/build.yml) runs the full ARM64 build and emulator checks for a new upstream version/commit or a manual dispatch; merging maintenance-only edits does not rebuild or republish an already verified release. Use manual dispatch when a same-version patch or build-script change needs a full binary rebuild. Documentation changes use the [docs workflow](.github/workflows/package-release-docs.yml), which repackages the latest verified release and proves that all five executable hashes are unchanged. Rust 1.95.0 builds the `aarch64-unknown-linux-musl` target; Zig 0.14.0 supplies the C/C++ cross compiler. The build script checks OpenAI's prebuilt V8 archive against the checksum committed in upstream, builds static musl OpenSSL, then builds `codex`, `codex-code-mode-host`, and `codex-responses-api-proxy`. A low-memory release profile is used. It downloads [ripgrep 15.2.0's official ARM64 musl asset](https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0), checks its published SHA-256 digest, and packages `rg` and its licenses. The archive includes OpenAI’s Apache 2.0 `LICENSE` and `NOTICE`. It also contains an empty `codex-resources/` directory for the usual package layout, diagnostics, build information, a matching direct-tool model catalog, patched-input hashes in `compat/PATCHINFO.json`, and SHA-256 sums for every file. This iSH build omits `bwrap` because its sandbox cannot run in iSH.

CI checks that each executable, including bundled `rg` and the diagnostic probe, is AArch64 ELF with no program interpreter or shared-library `NEEDED` entry. It verifies internal package checksums, runs `codex --version`, `rg --version`, and the syscall probe under `qemu-aarch64-static`, and publishes the archive and checksum both as an Actions artifact and a GitHub Release. The Release tag includes the Actions run number, so older builds remain available. `releases/latest` points to the newest successful published build.

### Recorded 0.159.3 verification

- The final published `ish-v0.159.3-5.1` archive was independently downloaded and verified: outer SHA-256 `c57f0dcc73b27d6de44abbb7f7f48a1ee7c0bf7b8652feab85f35c075a76d77d`, every internal checksum, all five static AArch64 ELF files, the upstream pin, and the matching GPT-6.1 catalog. It includes `BUILDINFO`, `BUILDINFO.txt`, the current guides, setup script, diagnostics, and licenses.

- The real source build completed for all three Codex executables, with static ARM64 ripgrep and the diagnostic probe. All five passed architecture, no-interpreter and no-shared-library checks. QEMU reported `codex-cli 0.159.3`; ripgrep and the fork/wait diagnostic passed.
- Native tests of the patched PTY crate passed **62 tests**. The syscall-fallback harness passed normal Linux, injected `EINVAL`, and fatal `EPERM` modes, including 20 worker-thread subprocesses and child cleanup.
- [Run 36913443330](https://github.com/leungantoine/codex-ish/actions/runs/36913443330) passed **eight** real-binary tool loops: GPT-6-Luna, Sol, GPT-6.1-Sol and Astra, each on native ARM64 Linux and unmodified iSH-AOK build 556. A local mock Responses server requested a random-marker shell command; the actual output and exit status 17 returned in the next model request. These are execution-path checks, not authenticated model inference. The installed helper also passed, including parsing an explicit GPT-6.1 model override.
- The same run passed app-server pipe and PTY shell calls inside unmodified iSH-AOK, with real output and exit status 17. The earlier app-server test failure was a host permissions error: model checks ran the emulator as root, then app-server checks tried to reuse its guest filesystem as a different host user. Using the same host identity resolved it without changing the Codex executables or iSH.
- Source-input hashes and the matching seven-entry direct-tool patch are recorded in `compat/PATCHINFO.json`. The [Bazel dependency lock patch](metadata/README.md) was generated from this source and retained for reproduction.
- Physical iOS testing and device authentication of this new version remain pending. The older user's GPT-6 success report and suspension failure are recorded separately below.

### Historical 0.158.0 verification

- The published archive was downloaded independently and its outer checksum and every internal executable checksum were verified.
- All five executables are ELF64 AArch64 with no `PT_INTERP` or shared-library `DT_NEEDED` dependencies.
- Under QEMU: `codex-cli 0.158.0`, both companion executables’ help, the device-auth CLI option, ripgrep searching a sample file, and the diagnostic fork/wait probe passed.
- [The subprocess verification script](tests/verify-subprocess.sh), run by the build workflow, compiles the exact patched PTY module and pinned Tokio into a native Linux harness. All three test modes passed. It checks 20 worker-thread shell spawns, stdout/stderr, exit status 17, and child termination/reaping. A test-only syscall shim exercises `prctl`/`waitid(P_PIDFD)` returning `EINVAL`, verifies the parent guard is skipped, and checks that `EPERM` remains fatal. The shim is never included in the Release.
- [Emulator run 36787134523](https://github.com/leungantoine/codex-ish/actions/runs/36787134523) built iSH-AOK Release 556 (`19b129bed782897a94d56e1855497f831cfdd405`) on an ARM64 Linux host and ran Alpine 3.23.3 through its guest kernel and ARM64 JIT. The downloaded, unchanged Release binary passed actual `command/exec` pipe and PTY shell calls, output capture and exit status 17. Worker-thread fork, posix_spawn, and the actual Codex setup-helper handshake also passed. The updated installer and embedded-mode launcher passed on native ARM64 Linux. This test uses guest `/bin/sh`; native iSH-AOK shell applets, the interactive TUI/model flow, device authentication, and iOS memory limits were not exercised.
- [Launcher verification run 36811040124](https://github.com/leungantoine/codex-ish/actions/runs/36811040124) tested the full installer and `--launcher-only` update, confirmed `code_mode_host` is disabled, and passed native ARM64 and iSH build 556 pipe/PTY shell calls with the compatibility settings. Its optional code-mode comparison reported **`oom-kill`, memory peak 2.0 GiB**, during actual V8 execution in both iSH cases, with and without OpenSSL CPU probes. Native Linux JavaScript execution passed. The overall workflow's success covers the launcher/shell checks; it does not mean the optional code-mode host passed.
- **User device verification:** the supplied screenshots showed all installation checksums passing, `codex-cli 0.158.0`, an interactive GPT-5.5 medium session, an actual shell tool execution of `printf 'ish-shell-ok\n'`, output `ish-shell-ok`, and exit status **0**. This is device evidence beyond Linux/QEMU/emulator checks. No user screenshot or raw device diagnostics are committed to this public repository.
- The original binaries are from Release `ish-v0.158.0-3`; the license-complete package `ish-v0.158.0-3.1` preserves those executable hashes. See [the verification run](https://github.com/leungantoine/codex-ish/actions/runs/36732272923) for the test results and publication.

These native harness tests exercise the patched source on Linux. They do not exercise the static ARM64 binary under iSH’s syscall implementation.

### GPT-6 code-mode investigation: emulator fix verified

The pinned catalog requires code mode for GPT-6-Luna and the other GPT-6/GPT-5.6 models. [Investigation and patch](experimental/README.md) identify a memory-management problem in iSH-AOK build 556: a 256 KiB V8 protection request materializes page-table entries for a roughly 1.3 TiB reservation. The unmodified emulator exceeds a 2 GiB memory limit and is killed. OpenSSL probe suppression and V8 JIT-less mode do not prevent it.

Changing iSH's `pt_set_flags` to use its existing `mem_lazy_populate` helper allowed the **unchanged released Codex code-mode host** to execute JavaScript, await a real IPC tool callback, return the callback's random nonce, shut down, and exit zero at **63 MiB maximum RSS**. Actual Codex pipe and PTY shell tests also passed after that emulator change. See [verification run 36813443833](https://github.com/leungantoine/codex-ish/actions/runs/36813443833) and the [candidate iSH patch](experimental/ish-aok-556-partial-mprotect.patch).

**Running V8 locally still needs an updated iSH-AOK iOS app.** The newer [Codex direct-tool patch](compat/README.md) bypasses that runtime and can be installed from the terminal using the current app and binary. No updated iOS app has been built here. The emulator patch remains a separate candidate requiring app-level review and regression testing; the finite lazy-reservation table can still force a large materialization if split slots run out. The user confirmed the direct-tool GPT-6 setup works. The recommended one-command setup makes plain `codex` use the direct catalog and disables daemon and code-mode hosting. The separate base installer retains its minimal launcher; `codex-gpt6` supplies the direct catalog for that advanced installation path.

### Diagnose the reported device crash

**Recent physical-device report (2026-10-01):** one MetricKit report records `Namespace RUNNINGBOARD, Code 0xdead10cc`, signal 9, for iSH-AOK build 556 on hardware `iPad14,6`. [Apple documents this code](https://developer.apple.com/documentation/xcode/sigkill) as termination for a file or SQLite database lock held during suspension. The other five supplied exports contain CPU exception diagnostics with no recorded crash diagnostic. They do not establish memory-pressure kills. The user was running Codex on a task and confirmed switching apps or locking the device around the crash, but could not identify the guest operation at closure. This is consistent with the reported suspension failure.

The inspected iSH-AOK 556 app uses a host SQLite database for filesystem metadata and has a suspension guard intended to drain those transactions. A remaining app-level suspension race is plausible, but the report lacks symbols and filesystem breadcrumbs needed to identify the specific lock. This failure is distinct from the separately reproduced V8 memory problem. The Codex upgrade is not claimed to fix it. Keep iSH visible and the device unlocked during work as a temporary precaution; this is not a proven fix. After a recurrence, share iSH's Support → Diagnostics export promptly, including launch journal, breadcrumbs and MetricKit diagnostics, and note the time and whether the app was backgrounded. Do not upload authentication files or private task contents to public issues.


A subsequent device test reached the interactive UI and received a model response, but `gpt-6-luna` refused the shell call because the code-mode host was disabled. Its displayed `ish-shell-ok` was **predicted output, not an executed command**. The pinned upstream catalog marks the GPT-6 and GPT-5.6 models as `code_mode_only`, which overrides feature flags. It marks `gpt-5.5` with no required code-mode override. Start a **new session with `--model gpt-5.5 --disable code_mode --disable code_mode_only`** for the direct-shell device test; do not resume the failing GPT-6 session. The follow-up device screenshot showed successful shell execution with GPT-5.5 at medium reasoning, real output `ish-shell-ok`, and exit status `0`. The first attempt failed because the previous `max` reasoning level was unsupported; selecting medium resolved that request error.

The device diagnostics recorded an ARM64 illegal instruction `0xd53b2400` at `0x4978184` in `codex-code-mode-host`. The published binary's ELF symbol table identifies that address as OpenSSL's `_armv8_rng_probe` (RNDR); the return address is in `arm_probe_for`. iSH records this event before delivering SIGILL, including signals caught by an application. OpenSSL catches unsupported CPU-feature probes, so the event alone does not establish the native app's crash cause.

[Code-mode reproduction run 36811040124](https://github.com/leungantoine/codex-ish/actions/runs/36811040124) completed a real host handshake and JavaScript execution on native ARM64 Linux. The same published host passed its handshake but failed during JavaScript execution under iSH build 556, both with normal CPU probing and with `OPENSSL_armcap=0` set **inside the guest**. Both emulator services reached the **2.0 GiB host memory limit** and reported **`oom-kill`** in about one second. The comparison retained logs. This establishes an emulator memory failure; attributing the iPhone app's closure to the same failure remains an inference until a native crash report confirms it. The subsequent successful direct-tool device test supports bypassing this runtime. Ordinary Codex pipe/PTY shell execution continued to pass. This reproduces an additional runtime failure absent from the earlier shell tests; the native iOS crash report is still needed to confirm the device's cause.

For the configuration that passed the interactive device test:

```sh
codex --no-daemon --model gpt-5.5 --disable code_mode_host \
  --disable code_mode --disable code_mode_only \
  -c 'model_reasoning_effort="medium"' \
  --sandbox danger-full-access --ask-for-approval on-request
```

Ask it to execute `printf 'ish-shell-ok\n'`. The installer supplies `--no-daemon --disable code_mode_host`; GPT-5.5 and medium reasoning must be selected as shown. The small interactive shell test is confirmed by the user's screenshot. If it still closes, reopen iSH-AOK, select **Support → Diagnostics → Share**, and attach the export, including the crash-time JSON in its `MetricKitDiagnostics` subfolder. Preserve the exact crash time, iSH build number, `codex --version`, and diagnostic probe output. A `JetsamEvent` should name the main `iSH-AOK` process with a termination reason before attributing its closure to memory pressure; a FileProvider-only termination does not establish that. Keep authentication files and tokens private.

If further isolation is needed, the previous diagnostic comparison also disables `shell_snapshot` and `unified_exec`, selecting the legacy shell path. These extra flags are not part of the default launcher.

**Verification limit:** QEMU runs ordinary Linux syscalls, not iSH-AOK's implementation. CI cannot prove that login or child shell commands work on your iPad. The user's successful `printf` device test covers the documented direct-tool configuration; code-mode hosting, daemon mode, other models, and broader workloads remain unverified or unsupported. A failure there should be reported with the diagnostic probe output, iSH-AOK version, and `codex --version`.

## Rebuild and update the pinned Codex release

The generated [Bazel lock update](metadata/README.md) was refreshed successfully and is retained as a patch with this kit. Apply it to the prepared upstream root when reproducing the source changes.

1. Inspect the latest stable `rust-v…` tag in `openai/codex`, especially `utils/pty/src/process_group.rs`, Tokio's selected version, its Unix reaper, the CLI binary list, and upstream release packaging. Check whether either compatibility fix has landed upstream. Do not reapply the old code blindly.
2. Start from that exact upstream tag and commit. Reapply only the compatibility changes still necessary. If Tokio has changed, vendor the matching locked version and update its pidfd fallback; update `Cargo.toml` and `Cargo.lock` together. If upstream provides a correct fallback, remove the local vendor override.
3. Update the single source pin in `codex-upstream.json` (tag, version, commit, and Tokio version). The preparation script and build workflows consume this manifest; do not duplicate those values in scripts. Recreate the small PTY patch against the new source. Do not replace newer manifests with files from the old overlay.
4. Inspect the new model catalog and package layout. CI discovers the direct-tool models from the generated catalog and exercises each one. Keep the V8 manifest and Tokio downloads checked against upstream committed checksums.
5. Open a pull request. The metadata workflow checks syntax, prepares the exact source, runs subprocess tests, and generates the Bazel lock update. On merge, a changed upstream tag/commit starts the full build, package checks, and unmodified iSH-AOK emulator tests; publication follows only if both jobs pass. If the pin is unchanged, the release gate skips rebuilding already verified binaries. Use manual dispatch to rebuild a same-pin patch or build-script change. Documentation-only changes use the fast archive refresh, which verifies that executable hashes stay unchanged. Finally test login and shell execution on the physical device; emulator success does not establish iOS suspension reliability.

The build uses one Cargo job, release LTO off, debug information 0, optimization level 2 and 16 codegen units, with codegen units 1 for `zbus` and `codex-model-provider`. `-C link-self-contained=no` lets Zig supply musl startup objects, avoiding duplicate `_start` symbols from Rust’s bundled objects. CI first tests this linker setup with a tiny static ARM64 program. OpenSSL settings loaded from `GITHUB_ENV` are exported using `set -a` while sourcing them. Hosted runners remove unused SDKs and allocate swap only when sufficient disk remains; retain both memory and disk headroom when changing the profile.

For a manual source build, use the checked-in pin and the same file layout as CI:

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
cargo metadata --manifest-path upstream/codex-rs/Cargo.toml --format-version 1 > /dev/null
upstream/scripts/build-ish-aarch64.sh
```

Use Ubuntu 24.04 with Rust 1.95.0, the ARM64 musl target, Zig 0.14.0, Perl, make, CMake, pkg-config, and Clang. The preparation script checks that the cloned tag resolves to the pinned commit. This is a maintenance path for builders; **the iPad installation uses the finished Release binary**.

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
