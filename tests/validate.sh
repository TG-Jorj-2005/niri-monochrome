#!/usr/bin/env bash
# Static validation: QML load check (every component instantiated once in a headless Quickshell run),
# shell script syntax, JSON config, desktop entry, niri config. Exit 1 on any failure.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"; fail=0
say() { printf '%-46s %s\n' "$1" "$2"; }
# shell scripts
shopt -s nullglob
scripts=("$here"/scripts/*.sh "$here"/tests/*.sh)
if ((${#scripts[@]} == 0)); then say "bash -n scripts" "no shell scripts found"; fi
for s in "${scripts[@]}"; do
  if bash -n "$s"; then say "bash -n $(basename "$s")" ok
  else say "bash -n $(basename "$s")" FAIL; fail=1; fi
done
# JSON
for j in "$HOME/.config/niri-monochrome/config.json" "$HOME/.local/state/niri-monochrome/state.json"; do
  [ -f "$j" ] || continue
  if python3 -I -c "import json,sys; json.load(open(sys.argv[1]))" "$j"; then say "json $(basename "$j")" ok
  else say "json $(basename "$j")" FAIL; fail=1; fi
done
# desktop entry
d="$HOME/.local/share/applications/niri-monochrome-settings.desktop"
if [ -f "$d" ]; then
  if desktop-file-validate "$d"; then say "desktop entry" ok
  else say "desktop entry" FAIL; fail=1; fi
fi
# niri config
if command -v niri >/dev/null; then
  if niri validate >/dev/null 2>&1; then say "niri validate" ok
  else say "niri validate" FAIL; fail=1; fi
fi
# Each load gets a private bus and temporary state; also validate the actual entrypoint.
for entry in selftest-qml.qml selftest-core.qml selftest-wallpaper.qml shell.qml; do
  if python3 "$here/tests/run-qml.py" "$here/$entry"; then say "$entry" ok
  else say "$entry" FAIL; fail=1; fi
done
exit "$fail"
