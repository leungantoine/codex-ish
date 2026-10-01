# Codex 0.159.3 dependency metadata

`bazel-dependency-lock.patch` is the actual `MODULE.bazel.lock` update produced by
`just bazel-lock-update` against OpenAI commit
`01fc69f4026735edfdf6789820549727a4867b11`, after applying the iSH source preparation
and resolving the release workspace version bump with `cargo metadata`.

It changes Tokio's cached crate metadata from the registry crate to the patched
local `vendor/tokio-1.52.3` input. The Cargo binaries do not use Bazel's lockfile.
The update is retained because upstream's AGENTS.md requires refreshing it when
Cargo dependency selection changes.

Apply from the prepared upstream source root:

```sh
git apply /path/to/codex-ish/metadata/bazel-dependency-lock.patch
```

Successful generation and read-only export:
https://github.com/leungantoine/codex-ish/actions/runs/36903463649

The patch was retrieved from the successful job log, decoded, and checked for
clean application against the pinned upstream lockfile. No automatic workflow
commit permission was added.
