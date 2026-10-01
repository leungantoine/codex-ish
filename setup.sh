#!/bin/sh
# Install the released binaries, direct tools, and startup PATH for iSH.
set -eu
if [ "$(uname -m)" != aarch64 ]; then
  echo 'Select the iSH-AOK ARM64 Alpine root first (uname -m must be aarch64).' >&2
  exit 1
fi
for command in curl sha256sum tar mktemp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo 'Run: apk add ca-certificates curl tar coreutils git bash' >&2
    exit 1
  fi
done
setup_base=${CODEX_ISH_SETUP_BASE:-https://raw.githubusercontent.com/leungantoine/codex-ish/main}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
curl -fL --retry 3 "$setup_base/install.sh" -o "$work/install.sh"
sh "$work/install.sh"
curl -fL --retry 3 "$setup_base/install-direct-tools.sh" -o "$work/install-direct-tools.sh"
sh "$work/install-direct-tools.sh"

# The helper always executes the real binary, with the matching direct catalog.
launcher="$HOME/.local/bin/.codex-startup-$$"
cat > "$launcher" <<'LAUNCHER'
#!/bin/sh
exec "$HOME/.local/bin/codex-gpt6" "$@"
LAUNCHER
chmod 0755 "$launcher"
mv -f "$launcher" "$HOME/.local/bin/codex"

path_line='export PATH="$HOME/.local/bin:$PATH"'
for profile in .profile .bashrc .zshrc .bash_profile .bash_login; do
  # Do not create a Bash login profile that would hide an existing .profile.
  case "$profile" in .bash_profile|.bash_login) [ -f "$HOME/$profile" ] || continue ;; esac
  if ! grep -Fqx "$path_line" "$HOME/$profile" 2>/dev/null; then
    printf '\n# Codex for iSH startup\n%s\n' "$path_line" >> "$HOME/$profile"
  fi
done
echo 'Installed. In a new iSH session, run: codex'
echo 'For this session: export PATH="$HOME/.local/bin:$PATH"'
echo 'If you are not signed in yet, run: codex login --device-auth'
