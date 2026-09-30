#!/bin/sh
# Install the checked GitHub Release into the current iSH user's home.
set -eu

if [ "$(uname -m)" != aarch64 ]; then
  echo 'This build requires the iSH-AOK ARM64 Alpine root (uname -m: aarch64).' >&2
  exit 1
fi
for command in curl sha256sum tar mktemp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing $command. Run: apk add ca-certificates curl tar coreutils" >&2
    exit 1
  fi
done

release_base=${CODEX_ISH_RELEASE_BASE:-https://github.com/leungantoine/codex-ish/releases/latest/download}
archive=codex-ish-aarch64.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
curl -fL --retry 3 "$release_base/$archive" -o "$work/$archive"
curl -fL --retry 3 "$release_base/$archive.sha256" -o "$work/$archive.sha256"
(cd "$work" && sha256sum -c "$archive.sha256")

mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
destination="$HOME/.local/opt/codex-ish"
stage="$HOME/.local/opt/.codex-ish-new-$$"
mkdir "$stage"
tar -xzf "$work/$archive" -C "$stage"
for name in codex codex-code-mode-host codex-responses-api-proxy codex-path/rg; do
  if [ ! -x "$stage/$name" ]; then
    echo "Archive is missing executable $name" >&2
    exit 1
  fi
done
(cd "$stage" && sha256sum -c SHA256SUMS)
if [ -d "$destination" ]; then
  backup="$HOME/.local/opt/.codex-ish-old-$$"
  mv "$destination" "$backup"
  mv "$stage" "$destination"
  rm -rf "$backup"
else
  mv "$stage" "$destination"
fi
ln -sfn "$destination/codex" "$HOME/.local/bin/codex"
ln -sfn "$destination/codex-path/rg" "$HOME/.local/bin/rg"
echo "Installed $destination/codex"
echo 'Add ~/.local/bin to PATH and run: codex --version'
