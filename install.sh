#!/bin/sh
# Install the checked GitHub Release into the current iSH user's home.
set -eu

write_launcher() {
  mkdir -p "$HOME/.local/bin"
  launcher="$HOME/.local/bin/.codex-ish-launcher-$$"
  cat > "$launcher" <<'SH'
#!/bin/sh
# iSH's code-mode host fails during V8 execution. Keep direct shell tools.
if [ "${CODEX_ISH_USE_CODE_MODE_HOST:-0}" != 1 ]; then
  set -- --disable code_mode_host "$@"
fi
# The shared daemon is unsupported in this iSH build. Use the embedded server.
if [ "${CODEX_ISH_USE_DAEMON:-0}" = 1 ]; then
  exec "$HOME/.local/opt/codex-ish/codex" "$@"
fi
exec "$HOME/.local/opt/codex-ish/codex" --no-daemon "$@"
SH
  chmod 0755 "$launcher"
  # Rename over the old symlink: writing through it would overwrite the binary.
  mv -f "$launcher" "$HOME/.local/bin/codex"
  if [ -x "$HOME/.local/opt/codex-ish/codex-gpt6" ]; then
    cp "$HOME/.local/opt/codex-ish/codex-gpt6" "$HOME/.local/bin/.codex-gpt6-new-$$"
    mv -f "$HOME/.local/bin/.codex-gpt6-new-$$" "$HOME/.local/bin/codex-gpt6"
  fi
}

if [ "${1:-}" = --launcher-only ] && [ "$#" = 1 ]; then
  if [ ! -x "$HOME/.local/opt/codex-ish/codex" ]; then
    echo 'Install Codex first; --launcher-only requires an existing executable.' >&2
    exit 1
  fi
  write_launcher
  echo 'Updated launcher: --no-daemon and --disable code_mode_host'
  exit 0
fi
if [ "$#" != 0 ]; then
  echo 'Usage: sh install.sh [--launcher-only]' >&2
  exit 1
fi

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
destination="$HOME/.local/opt/codex-ish"
stage=
backup=
cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  rm -rf "$work"
  if [ -n "$stage" ] && [ -d "$stage" ]; then rm -rf "$stage"; fi
  if [ -n "$backup" ] && [ -d "$backup" ]; then
    if [ ! -e "$destination" ]; then
      mv "$backup" "$destination" || echo "Could not restore previous installation from $backup" >&2
    else
      rm -rf "$backup"
    fi
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
curl -fL --retry 3 "$release_base/$archive" -o "$work/$archive"
curl -fL --retry 3 "$release_base/$archive.sha256" -o "$work/$archive.sha256"
(cd "$work" && sha256sum -c "$archive.sha256")

mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
stage="$HOME/.local/opt/.codex-ish-new-$"
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
  backup="$HOME/.local/opt/.codex-ish-old-$"
  mv "$destination" "$backup"
  if ! mv "$stage" "$destination"; then
    mv "$backup" "$destination"
    backup=
    echo 'Could not install the new package; restored the previous installation.' >&2
    exit 1
  fi
  stage=
  rm -rf "$backup"
  backup=
else
  mv "$stage" "$destination"
  stage=
fi
write_launcher
ln -sfn "$destination/codex-path/rg" "$HOME/.local/bin/rg"
echo "Installed $destination/codex"
echo 'Add ~/.local/bin to PATH and run: codex --version (daemon and code-mode host disabled)'
