#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
install -Dm644 "$project_dir/assets/applications/niri-monochrome-screenshot.desktop" "$data_dir/applications/niri-monochrome-screenshot.desktop"
mkdir -p "$HOME/Pictures/Screenshots"
if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$data_dir/applications"; fi
