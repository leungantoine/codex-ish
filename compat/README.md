# GPT-6 direct-tool patch for Codex 0.158.0

This opt-in patch bypasses Codex's local V8 code-mode runtime. It uses the real
released Codex binary and its existing direct shell, approval, output capture,
and patch tools. It does not modify iSH-AOK or execute JavaScript through a
replacement evaluator.

## Install on the device

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

The installer separately passed a checksum and launcher argument test.
**These tests use a mock backend, not authenticated GPT-6 inference.** They prove
the real Codex tool execution path, not real service acceptance or model tool
choice. Actual GPT-6 inference and this configuration's interactive iOS behavior
still need the device test above. GPT-5.6 shares the metadata patch but was not
included in the three-model execution test.

OpenAI's [GPT-6-Luna documentation](https://developers.openai.com/api/docs/models/gpt-6-luna)
lists Responses API function calling support. That supports trying direct tools;
it does not guarantee compatibility with every Codex-specific backend route or
account.

If the service rejects direct tools or the model still asks for code mode, retain
the real error text and report it. Do not repeatedly enable the V8 host on build
556. Start normal `codex` with the documented GPT-5.5 configuration to return to
the device-tested path. Removing `~/.local/bin/codex-gpt6` and
`~/.local/opt/codex-ish-direct` removes this opt-in patch.
