#!/usr/bin/env bash
# Install the reference desktop configuration that ships with NIRI MONOCHROME.
#
#   bash scripts/install.sh --check     only report missing programs and fonts
#   bash scripts/install.sh --dry-run   show what would be copied, change nothing
#   bash scripts/install.sh             copy the files; changed files are backed up first
#
# Copies examples/niri, examples/bin, the mako/fuzzel/swaylock/alacritty configs and the
# desktop entries. An existing file that differs is renamed to <file>.bak-<timestamp>.
# The shell's own settings (~/.config/niri-monochrome/config.json) are not touched;
# the shell creates defaults on first start.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
bin_dir="$HOME/.local/bin"
stamp="$(date +%Y%m%d-%H%M%S)"
mode="install"
case "${1:-}" in
    --check) mode="check" ;;
    --dry-run) mode="dry-run" ;;
    "") ;;
    *) printf 'usage: %s [--check|--dry-run]\n' "$0" >&2; exit 2 ;;
esac

# command -> Fedora package
declare -A pkg=(
    [qs]=quickshell [niri]=niri [python3]=python3 [pw-cat]=pipewire-utils [wpctl]=wireplumber
    [nmcli]=NetworkManager [brightnessctl]=brightnessctl [notify-send]=libnotify [busctl]=systemd
    [alacritty]=alacritty [mako]=mako [makoctl]=mako [fuzzel]=fuzzel [swaylock]=swaylock
    [swayidle]=swayidle [cliphist]=cliphist [wl-copy]=wl-clipboard [wl-paste]=wl-clipboard
    [grim]=grim [slurp]=slurp [magick]=ImageMagick [wf-recorder]=wf-recorder [playerctl]=playerctl
    [xwayland-satellite]=xwayland-satellite [nm-applet]=network-manager-applet
    [blueman-applet]=blueman [blueman-manager]=blueman [nm-connection-editor]=nm-connection-editor
    [swappy]=swappy [wlsunset]=wlsunset
)
required=(qs niri python3 pw-cat wpctl nmcli brightnessctl notify-send busctl)
examples=(alacritty mako makoctl fuzzel swaylock swayidle cliphist wl-copy wl-paste grim slurp magick
          wf-recorder playerctl xwayland-satellite nm-applet blueman-applet)
optional=(swappy wlsunset nm-connection-editor blueman-manager)
fonts=("Inter" "JetBrains Mono" "Adwaita Sans")
declare -A font_pkg=([Inter]=rsms-inter-fonts ["JetBrains Mono"]=jetbrains-mono-fonts ["Adwaita Sans"]=adwaita-sans-fonts)

missing_pkgs=()
check_group() {
    local label=$1; shift
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then continue; fi
        printf '  missing (%s): %s  [%s]\n' "$label" "$cmd" "${pkg[$cmd]}"
        [ "$label" = optional ] || missing_pkgs+=("${pkg[$cmd]}")
    done
}
check() {
    echo "Programs:"
    check_group required "${required[@]}"
    check_group examples "${examples[@]}"
    check_group optional "${optional[@]}"
    [ -x /usr/libexec/polkit-mate-authentication-agent-1 ] ||
        { echo "  missing (examples): polkit agent  [mate-polkit]"; missing_pkgs+=(mate-polkit); }
    echo "Fonts:"
    local f families
    # Read the list once: `fc-list | grep -q` would trip pipefail when grep exits early (SIGPIPE).
    families="$(fc-list : family 2>/dev/null || true)"
    for f in "${fonts[@]}"; do
        grep -qi "^$f\(,\|$\)" <<<"$families" ||
            { printf '  missing: %s  [%s]\n' "$f" "${font_pkg[$f]}"; missing_pkgs+=("${font_pkg[$f]}"); }
    done
    command -v niri >/dev/null && echo "niri: $(niri --version)"
    command -v qs >/dev/null && echo "quickshell: $(qs --version | head -1)"
    if ((${#missing_pkgs[@]})); then
        printf 'Install with:\n  sudo dnf install %s\n' "$(printf '%s\n' "${missing_pkgs[@]}" | sort -u | tr '\n' ' ')"
    else
        echo "All required and example programs are installed."
    fi
}

place() { # source destination mode
    local src=$1 dst=$2 perm=$3
    if [ -e "$dst" ] && cmp -s "$src" "$dst"; then printf '  same      %s\n' "$dst"; return; fi
    if [ "$mode" = dry-run ]; then
        printf '  %-9s %s\n' "$([ -e "$dst" ] && echo replace || echo new)" "$dst"; return
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ]; then mv -- "$dst" "$dst.bak-$stamp"; printf '  replaced  %s  (backup: %s)\n' "$dst" "$dst.bak-$stamp"
    else printf '  new       %s\n' "$dst"; fi
    install -m "$perm" "$src" "$dst"
}

check
[ "$mode" = check ] && exit 0

expected="$config_home/quickshell/niri-monochrome"
if [ "$(cd "$expected" 2>/dev/null && pwd -P)" != "$(cd "$project_dir" && pwd -P)" ]; then
    printf '\nNote: the project is at %s; "qs -c niri-monochrome" expects it at %s.\n' "$project_dir" "$expected"
fi

echo
echo "Files ($mode):"
for f in "$project_dir"/examples/niri/*.kdl; do place "$f" "$config_home/niri/$(basename "$f")" 644; done
for f in "$project_dir"/examples/bin/*; do place "$f" "$bin_dir/$(basename "$f")" 755; done
place "$project_dir/examples/mako/config" "$config_home/mako/config" 644
place "$project_dir/examples/fuzzel/fuzzel.ini" "$config_home/fuzzel/fuzzel.ini" 644
place "$project_dir/examples/swaylock/config" "$config_home/swaylock/config" 644
place "$project_dir/examples/alacritty/alacritty.toml" "$config_home/alacritty/alacritty.toml" 644
for f in "$project_dir"/assets/applications/*.desktop; do place "$f" "$data_home/applications/$(basename "$f")" 644; done
[ "$mode" = dry-run ] && exit 0

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers" "$HOME/Videos/Recordings"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data_home/applications" || true
if command -v niri >/dev/null 2>&1; then
    if niri validate -c "$config_home/niri/config.kdl" >/dev/null 2>&1; then echo "niri validate: ok"
    else echo "niri validate: FAILED (run: niri validate -c $config_home/niri/config.kdl)"; fi
fi
case ":$PATH:" in *":$bin_dir:"*) ;; *) echo "Note: add $bin_dir to PATH; the niri config starts idle-manager from there." ;; esac
echo "Done. Put wallpapers in ~/Pictures/Wallpapers and log in to a niri session (startup.kdl starts the shell)."
