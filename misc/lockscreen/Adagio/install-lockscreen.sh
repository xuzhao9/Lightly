#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
system_shell=/usr/share/plasma/shells/org.kde.plasma.desktop
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
user_shells="$data_home/plasma/shells"
target="$user_shells/org.kde.plasma.desktop"
marker=.adagio-lockscreen-overlay

usage() {
    printf 'Usage: %s [--install|--test|--sync-wallpaper|--uninstall]\n' "$0"
}

case "${1:---install}" in
    --install|--test|--sync-wallpaper|--uninstall) action=${1:---install} ;;
    *) usage >&2; exit 2 ;;
esac

if [[ $# -gt 1 ]]; then
    usage >&2
    exit 2
fi

sync_wallpaper() {
    local desktop_wallpaper image plugin fill_mode

    if ! command -v qdbus6 >/dev/null || ! command -v kwriteconfig6 >/dev/null; then
        printf 'qdbus6 and kwriteconfig6 are required to sync the desktop wallpaper.\n' >&2
        return 1
    fi

    if ! desktop_wallpaper=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.wallpaper 0); then
        printf 'Could not read the current desktop wallpaper from Plasma.\n' >&2
        return 1
    fi

    plugin=$(sed -n 's/.*wallpaperPlugin: //p' <<< "$desktop_wallpaper")
    image=$(sed -n 's/^Image: //p' <<< "$desktop_wallpaper")
    fill_mode=$(sed -n 's/^FillMode: //p' <<< "$desktop_wallpaper")
    if [[ $plugin != org.kde.image || -z $image || ! $fill_mode =~ ^[0-9]+$ ]]; then
        printf 'The current desktop wallpaper is not a static Plasma image.\n' >&2
        return 1
    fi

    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
        --group org.kde.image --group General --key Image "$image"
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
        --group org.kde.image --group General --key FillMode "$fill_mode"
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
        --group org.kde.image --group General --key Blur false
    printf 'Lock screen wallpaper now matches desktop screen 0: %s\n' "$image"
}

if [[ $action == --sync-wallpaper ]]; then
    sync_wallpaper
    exit
fi

if [[ $action == --uninstall ]]; then
    if [[ ! -e $target ]]; then
        printf 'Adagio is not installed.\n'
        exit 0
    fi
    if [[ ! -f $target/$marker ]]; then
        printf 'Refusing to remove an existing Plasma shell that Adagio did not install: %s\n' "$target" >&2
        exit 1
    fi
    rm -rf -- "$target"
    printf 'Removed Adagio lock screen overlay.\n'
    exit 0
fi

if [[ ! -f $system_shell/metadata.json || ! -f $system_shell/contents/lockscreen/LockScreen.qml ]]; then
    printf 'The installed Plasma 6 desktop shell was not found at %s\n' "$system_shell" >&2
    exit 1
fi

if [[ $action == --install && -e $target && ! -f $target/$marker ]]; then
    printf 'Refusing to replace an existing user Plasma shell: %s\n' "$target" >&2
    exit 1
fi

if [[ $action == --test ]]; then
    staging=$(mktemp -d)
else
    mkdir -p -- "$user_shells"
    staging=$(mktemp -d "$user_shells/.adagio.XXXXXXXX")
fi
cleanup() { rm -rf -- "$staging"; }
trap cleanup EXIT

cp -a -- "$system_shell/." "$staging/"
cp -- "$script_dir"/contents/lockscreen/*.qml "$staging/contents/lockscreen/"
cp -- "$script_dir/contents/lockscreen/login.svg" "$staging/contents/lockscreen/"
printf 'Adagio shell overlay\n' > "$staging/$marker"

if [[ $action == --test ]]; then
    /usr/libexec/kscreenlocker_greet --testing --shell "$staging"
    exit
fi

backup=
if [[ -e $target ]]; then
    backup=$(mktemp -d "$user_shells/.adagio-backup.XXXXXXXX")
    rmdir -- "$backup"
    mv -- "$target" "$backup"
fi

if mv -- "$staging" "$target"; then
    trap - EXIT
    if [[ -n $backup ]]; then
        rm -rf -- "$backup"
    fi
    printf 'Installed Adagio lock screen at %s\n' "$target"
    sync_wallpaper || printf 'Adagio was installed; run %s --sync-wallpaper from a Plasma session to match its wallpaper.\n' "$0" >&2
else
    if [[ -n $backup ]]; then
        mv -- "$backup" "$target"
    fi
    exit 1
fi
