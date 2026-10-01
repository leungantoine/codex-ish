#!/bin/sh
# Opt-in GPT-6 direct tools for the existing Codex 0.158.0 iSH release.
set -eu

binary="$HOME/.local/opt/codex-ish/codex"
if [ ! -x "$binary" ]; then
  echo 'Install codex-ish first using install.sh.' >&2
  exit 1
fi
if [ -x "$HOME/.local/opt/codex-ish/codex-gpt6" ] && [ -r "$HOME/.local/opt/codex-ish/compat/models-direct.json" ]; then
  mkdir -p "$HOME/.local/bin"
  cp "$HOME/.local/opt/codex-ish/codex-gpt6" "$HOME/.local/bin/.codex-gpt6-new-$$"
  mv -f "$HOME/.local/bin/.codex-gpt6-new-$$" "$HOME/.local/bin/codex-gpt6"
  echo 'Installed codex-gpt6 using the catalog bundled with this Codex release.'
  exit 0
fi
for command in curl sha256sum mktemp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo 'Run: apk add ca-certificates curl coreutils' >&2
    exit 1
  fi
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
catalog_url=${CODEX_ISH_DIRECT_CATALOG_URL:-https://raw.githubusercontent.com/leungantoine/codex-ish/e1717ccf0f77a58ef8617b80ccfb672688aa4a31/compat/models-direct.json}
curl -fL --retry 3 "$catalog_url" -o "$work/models-direct.json"
printf '%s  models-direct.json\n' bdfadcf32a9d879e53e89825fd8d3fd133c869d0baa2d39a3772172ca8b565ae > "$work/SHA256SUMS"
(cd "$work" && sha256sum -c SHA256SUMS)
mkdir -p "$HOME/.local/opt/codex-ish-direct" "$HOME/.local/bin"
cp "$work/models-direct.json" "$HOME/.local/opt/codex-ish-direct/models-direct.json.new"
mv "$HOME/.local/opt/codex-ish-direct/models-direct.json.new" "$HOME/.local/opt/codex-ish-direct/models-direct.json"
cat > "$work/codex-gpt6" <<'LAUNCHER'
#!/bin/sh
exec "$HOME/.local/opt/codex-ish/codex" \
  --no-daemon --disable code_mode_host --disable code_mode --disable code_mode_only \
  -c 'model="gpt-6-luna"' -c 'model_reasoning_effort="medium"' \
  -c "model_catalog_json=\"$HOME/.local/opt/codex-ish-direct/models-direct.json\"" "$@"
LAUNCHER
chmod 755 "$work/codex-gpt6"
cp "$work/codex-gpt6" "$HOME/.local/bin/.codex-gpt6-new-$$"
mv "$HOME/.local/bin/.codex-gpt6-new-$$" "$HOME/.local/bin/codex-gpt6"
echo 'Installed codex-gpt6: GPT-6-Luna, medium reasoning, direct tools.'
echo 'Start: codex-gpt6 --sandbox danger-full-access --ask-for-approval on-request'
echo 'Real GPT-6 service and device compatibility still require a shell-tool test.'
