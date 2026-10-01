# iSH-AOK build 556: V8 memory investigation

This is an emulator-side candidate patch, not an installable Codex update or an iOS app build. It applies to `emkey1/ish-AOK` tag `builds/iSH-AOK_556`, commit `19b129bed782897a94d56e1855497f831cfdd405`.

**Alternative available:** the newer [Codex direct-tool patch](../compat/README.md) bypasses V8 using a terminal-installable model-catalog override. The emulator patch below is only needed to run V8 locally; it is not required to try GPT-6 with direct tools.

## Reproduction and cause

Use `.github/workflows/reproduce-ish.yml`. It checks the existing release archive and all internal executable checksums, builds the pinned ARM64 guest emulator on native ARM64 Linux, and speaks the actual code-mode host's framed IPC protocol. No model authentication is needed. Experimental services have a 2 GiB cgroup memory limit and no swap so a failed case cannot exhaust the runner.

The released host works on native Linux. On the unmodified emulator it completes the IPC handshake but is killed during V8 execution at the 2 GiB host memory limit, with or without guest `OPENSSL_armcap=0` or V8 `--jitless`.

The lazy-memory trace records `materialize_range [d00000,16500000) for req [1d00000,1d00040) flags=0` (guest page numbers, 4 KiB each). The reservation is 1.34375 TiB; the requested subrange is only 256 KiB. In `emu/memory.c`, `pt_set_flags` calls `mem_lazy_materialize_range`, expanding every overlapping reservation into per-page metadata, even when the protection request touches only a small part.

## Candidate change and measured result

`ish-aok-556-partial-mprotect.patch` replaces that call with existing `mem_lazy_populate`. That helper materializes the requested interval and preserves untouched lazy reservation sides when the reservation table can accommodate the split.

[Run 36813062230](https://github.com/leungantoine/codex-ish/actions/runs/36813062230) tested the exact released, unchanged Codex host with this emulator change. Handshake, real JavaScript output `ish-code-mode-ok`, session shutdown, and exit status zero passed. Maximum process RSS was 63,080 KiB (61.6 MiB). The diagnostic JIT-less copy also passed at 46,816 KiB. The original emulator failed all three modes in the same job with `oom-kill`. The diagnostic host changes a unique fixed-length V8 flag string in a copy only; it is never a release asset and is unnecessary for the passing default case.

## Tool callback and shell regression verification

[Run 36813443833](https://github.com/leungantoine/codex-ish/actions/runs/36813443833) repeated the comparison with a real awaited IPC callback. JavaScript invoked `tools.echo`, the client verified the arguments and returned a fresh random nonce, and the JavaScript result contained that nonce. Both the unchanged default host and the diagnostic JIT-less host passed under the patched emulator. The unchanged host reached 64,504 KiB maximum RSS (63.0 MiB) including this callback test and exited zero. The original emulator again hit the 2 GiB limit in all three cases. After the emulator patch, actual Codex app-server pipe and PTY shell commands both returned the expected output and exit status 17. No GPT-6 request or login was made; the callback is a protocol test, not a model test.

## Limits and next integration step

This establishes the emulator failure mechanism and a working candidate for the small V8 test. It does not establish the original iPhone's native crash cause or prove authenticated GPT-6 compatibility on iOS. The iPhone diagnostic's caught OpenSSL CPU probe alone is not proof of the crash cause.

The patch must be integrated, reviewed, and tested in an iSH-AOK iOS app build. Reinstalling the current Codex archive cannot change iSH's kernel. The helper can still fall back to materializing a whole reservation when lazy split slots are exhausted; this patch is not a complete guarantee for all memory layouts. Allocation-error propagation, invalid ranges, protections, fork/COW, repeated sessions, iOS 16 KiB host pages, and memory limits deserve app-level regression coverage before a general release.

For the device-tested path, retain the documented GPT-5.5 direct-tool configuration. The separate GPT-6 direct-tool patch has passed mock-backend tool roundtrips under unmodified iSH and still needs authenticated device testing. Current stable Codex binaries and the latest release are unchanged.
