# GPT-6 direct tools for Codex on iSH-AOK

This opt-in patch bypasses Codex's local V8 code-mode runtime. It uses the real
released Codex binary and its existing direct shell, approval, output capture,
and patch tools. It does not modify iSH-AOK or execute JavaScript through a
replacement evaluator.


## Recommended installation and upgrade

Use the one-command [setup in the main README](../README.md#install-or-upgrade-with-one-command-recommended), then run `codex`. Setup saves PATH for future iSH sessions and configures plain `codex` with GPT-6-Luna, medium reasoning, direct tools, the daemon disabled, and unsandboxed guest access with approval on request. Guest files and network are accessible. Keep iSH visible during tasks because the reported iOS suspension lock failure is not claimed fixed.

Codex 0.159.3 bundles a matching catalog derived from OpenAI commit `01fc69f4026735edfdf6789820549727a4867b11`. It changes only seven tool-mode fields: the three GPT-6 entries, GPT-6.1-Sol, and the three GPT-5.6 entries. Source pin, original Tokio checksum, and input hashes are in the archive's `compat/PATCHINFO.json`. Use `codex --model gpt-6.1-sol` with this package to select GPT-6.1-Sol. The helper installation recognizes the bundled catalog and does not download the old fallback catalog.

The user confirmed that the earlier GPT-6 direct-tool setup works on their device. That report does not establish every model or task, and physical-device testing of 0.159.3 is still required.

The 0.158.0 instructions and recorded checks below describe the historical fallback retained for that older binary.

## Historical 0.158.0 fallback installation

First install the normal codex-ish release. Then run:

```sh
cd "$HOME"
curl -fL --retry 3 \
  https://raw.githubusercontent.com/leungantoine/codex-ish/main/install-direct-tools.sh \
  -o install-direct-tools.sh
sh install-direct-tools.sh
export PATH="$HOME/.local/bin:$PATH"
codex-gpt6 --sandbox danger-full-access --ask-for-approval on-request
```

The installer verifies the catalog's pinned SHA256 and creates
`~/.local/bin/codex-gpt6`. The existing `codex` launcher, executable, authentication,
and user config are preserved. No binary rebuild or 203 MiB download is needed.
The separate compatibility catalog survives a normal binary reinstall.

The launcher starts a new session with GPT-6-Luna, medium reasoning, the daemon
disabled, code-mode hosting disabled, and the compatibility catalog. To choose
another model:

```sh
codex-gpt6 --model gpt-6-sol --sandbox danger-full-access --ask-for-approval on-request
codex-gpt6 --model gpt-6-astra --sandbox danger-full-access --ask-for-approval on-request
```

Ask the model:

```text
Actually execute printf 'ish-gpt6-shell-ok\n' using the shell tool. Show the actual output and exit status. Do not predict the output.
```

Success requires a real shell tool card, output `ish-gpt6-shell-ok`, and exit
status 0. A model saying what the output should be is not success. Use a new
session rather than resuming the prior code-mode-only conversation. Keep the
app open while testing. Guest commands can access Alpine files and the network;
iSH lacks Codex's normal Linux sandbox.

## What changes

`models-direct.json` is copied from OpenAI source commit
`064c6b8c737f5b41d171fdda80bd9ef10ad06eb3`,
`codex-rs/models-manager/models.json`. Only `tool_mode` changes, from
`code_mode_only` to `direct`, for these six existing model entries:

- `gpt-6-luna`, `gpt-6-sol`, `gpt-6-astra`
- `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.6-sol`

The names sent to the backend, reasoning settings, prompts, context limits,
Responses Lite settings, and other metadata are unchanged. Codex's supported
`model_catalog_json` option loads this as a static catalog; remote catalog refresh
cannot replace the override during the session. Newer model names, including
GPT-6.1, are not added or claimed tested by this pinned patch.

Catalog SHA256:

```text
bdfadcf32a9d879e53e89825fd8d3fd133c869d0baa2d39a3772172ca8b565ae
```

The complete upstream catalog is retained. Do not copy an API key or an
authentication file into it. A later Codex upgrade needs a fresh catalog and
verification of its tool selection behavior.

## Verification and limits

[Run 36888592596](https://github.com/leungantoine/codex-ish/actions/runs/36888592596)
downloaded and checksum-verified the real published ARM64 binaries, built
unmodified iSH-AOK build 556, and ran them on Alpine 3.23.3.

For each of GPT-6-Luna, Sol, and Astra, on native ARM64 Linux and under iSH:

1. The actual request retained the requested model name and exposed direct
   `exec_command` and `write_stdin` schemas, with no code-mode `exec` tool.
2. A local mock Responses server returned a shell tool call containing a random
   output marker. Codex executed the command and returned that marker and exit
   status 17 to the next inference request.
3. Codex completed the tool loop and exited zero without invoking the code-mode
   host. The iSH app kernel was not patched for this test.

[Final run 36893869807](https://github.com/leungantoine/codex-ish/actions/runs/36893869807) repeated those six execution cases, installed the real launcher with its checksum-verified catalog, verified an explicit Astra model override parses, and completed the actual launcher's Sol direct shell loop against the mock server. The installer also passed a local checksum and argument test.
**These tests use a mock backend, not authenticated GPT-6 inference.** They prove
the real Codex tool execution path, not real service acceptance or model tool
choice. The user subsequently confirmed the earlier GPT-6 setup works on their device.
Each model and larger workloads still need separate device testing. GPT-5.6 shares the metadata patch but was not
included in the three-model execution test.

OpenAI's [GPT-6-Luna documentation](https://developers.openai.com/api/docs/models/gpt-6-luna)
lists Responses API function calling support. That supports trying direct tools;
it does not guarantee compatibility with every Codex-specific backend route or
account.

If the service rejects direct tools or the model still asks for code mode, retain
the real error text and report it. Do not repeatedly enable the V8 host on build
556. After the recommended setup, use `codex --model gpt-5.5` to select the
device-tested model; the direct-tool flags and medium reasoning remain active.
To restore the base launcher, run `sh install-codex-ish.sh --launcher-only`
with the downloaded base installer. Only after restoring that launcher should
you remove `~/.local/bin/codex-gpt6` or `~/.local/opt/codex-ish-direct`; plain
`codex` installed by setup depends on the helper.
