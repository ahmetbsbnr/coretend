#!/bin/bash
set -euo pipefail

usage() {
  printf 'Usage: %s --app CoreTend.app --destination EXISTING_DIRECTORY\n' "$0" >&2
}

app_arg=""
destination_arg=""
while (($#)); do
  case "$1" in
    --app)
      (($# >= 2)) || { usage; exit 64; }
      app_arg="$2"; shift 2 ;;
    --destination)
      (($# >= 2)) || { usage; exit 64; }
      destination_arg="$2"; shift 2 ;;
    *) usage; exit 64 ;;
  esac
done

[[ -n "$app_arg" && -n "$destination_arg" ]] || { usage; exit 64; }
[[ ! -L "$app_arg" && -d "$app_arg" ]] || { printf 'Source app must be an existing non-symlink bundle.\n' >&2; exit 1; }
[[ "$(basename "$app_arg")" == "CoreTend.app" ]] || { printf 'Source bundle must be named CoreTend.app.\n' >&2; exit 1; }
[[ -d "$destination_arg" && ! -L "$destination_arg" ]] || { printf 'Destination must be an existing non-symlink directory.\n' >&2; exit 1; }

source_parent="$(cd "$(dirname "$app_arg")" && pwd -P)"
destination="$(cd "$destination_arg" && pwd -P)"
source_app="$source_parent/CoreTend.app"
target="$destination/CoreTend.app"
[[ -f "$source_app/Contents/Info.plist" && -x "$source_app/Contents/MacOS/CoreTendApp" ]] || { printf 'Source bundle is incomplete.\n' >&2; exit 1; }
plutil -lint "$source_app/Contents/Info.plist" >/dev/null
[[ ! -e "$target" && ! -L "$target" ]] || { printf 'Destination already contains CoreTend.app; refusing replacement.\n' >&2; exit 1; }

stage="$(mktemp -d "$destination/.coretend-install.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$source_app" "$stage/CoreTend.app"
plutil -lint "$stage/CoreTend.app/Contents/Info.plist" >/dev/null
[[ -x "$stage/CoreTend.app/Contents/MacOS/CoreTendApp" ]] || { printf 'Staged app executable is missing.\n' >&2; exit 1; }
[[ ! -e "$target" && ! -L "$target" ]] || { printf 'Destination changed during install; refusing replacement.\n' >&2; exit 1; }
mv "$stage/CoreTend.app" "$target"
printf 'Installed local app: %s\n' "$target"
printf 'App data remains separate; this script does not launch or sign the app.\n'
