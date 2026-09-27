#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 --app CoreTend.app [--dry-run|--keep-data|--remove-all] [--include-legacy] [--yes]
  --dry-run        list selected paths and remove nothing (default)
  --keep-data      remove only the explicitly selected app bundle
  --remove-all     remove app bundle, current app data, and current preferences
  --include-legacy also remove pre-rename data; opt-in and always removed last
  --yes            skip interactive confirmation for a destructive mode
EOF
}

app_arg=""
mode="dry-run"
mode_selected=0
include_legacy=0
assume_yes=0
while (($#)); do
  case "$1" in
    --app)
      (($# >= 2)) || { usage; exit 64; }
      app_arg="$2"; shift 2 ;;
    --dry-run|--keep-data|--remove-all)
      ((mode_selected == 0)) || { usage; exit 64; }
      mode="${1#--}"; mode_selected=1; shift ;;
    --include-legacy) include_legacy=1; shift ;;
    --yes) assume_yes=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage; exit 64 ;;
  esac
done

[[ -n "$app_arg" && "$app_arg" == /* && "$(basename "$app_arg")" == "CoreTend.app" ]] || { usage; exit 64; }
[[ -d "$HOME" && ! -L "$HOME" && "$HOME" != / ]] || { printf 'HOME must be an existing non-symlink directory other than /.\n' >&2; exit 1; }
[[ ! -L "$app_arg" && -d "$app_arg" ]] || { printf 'Selected app must be an existing non-symlink bundle.\n' >&2; exit 1; }
[[ -f "$app_arg/Contents/Info.plist" && ! -L "$app_arg/Contents/Info.plist" && -f "$app_arg/Contents/MacOS/CoreTendApp" && ! -L "$app_arg/Contents/MacOS/CoreTendApp" ]] || {
  printf 'Selected app bundle is incomplete.\n' >&2; exit 1;
}

home_dir="$(cd -P -- "$HOME" && pwd -P)"
app_parent="$(cd -P -- "$(dirname "$app_arg")" && pwd -P)"
app_path="$app_parent/CoreTend.app"
support_dir="$home_dir/Library/Application Support/CoreTend-Reconstruction"
preferences_file="$home_dir/Library/Preferences/local.coretend.reconstruction.plist"
legacy_support="$home_dir/Library/Application Support/MacCareLocal"
legacy_support_alt="$home_dir/Library/Application Support/MacCare Local"
legacy_preferences="$home_dir/Library/Preferences/local.maccare.app.plist"

targets=("$app_path")
if [[ "$mode" == "remove-all" ]]; then
  targets+=("$support_dir" "$preferences_file")
fi
if ((include_legacy)); then
  targets+=("$legacy_support" "$legacy_support_alt" "$legacy_preferences")
fi

is_allowed() {
  local candidate="$1" allowed
  for allowed in "${targets[@]}"; do
    [[ "$candidate" == "$allowed" ]] && return 0
  done
  return 1
}

check_target() {
  local target="$1" parent_real
  is_allowed "$target" || { printf 'Refusing non-allowlisted path: %s\n' "$target" >&2; return 1; }
  [[ -e "$target" || -L "$target" ]] || return 2
  [[ ! -L "$target" ]] || { printf 'Refusing symlink target: %s\n' "$target" >&2; return 1; }
  parent_real="$(cd -P -- "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    printf 'Refusing target with unavailable parent: %s\n' "$target" >&2; return 1;
  }
  [[ "$parent_real/$(basename "$target")" == "$target" ]] || {
    printf 'Refusing target through symlinked parent: %s\n' "$target" >&2; return 1;
  }
  return 0
}

printf 'CoreTend local uninstall (mode: %s%s)\n' "$mode" "$([[ $include_legacy == 1 ]] && printf ', include legacy' || true)"
for target in "${targets[@]}"; do
  if check_target "$target"; then
    printf '  selected: %s\n' "$target"
  else
    result=$?
    [[ $result -eq 2 ]] || exit "$result"
    printf '  absent:   %s\n' "$target"
  fi
done

if [[ "$mode" == "dry-run" ]]; then
  printf 'Dry run: nothing removed. Choose --keep-data or --remove-all to continue.\n'
  exit 0
fi

if ((!assume_yes)); then
  printf 'Permanently remove selected paths? [y/N] '
  read -r reply
  case "$reply" in y|Y|yes|YES) ;; *) printf 'Cancelled; nothing removed.\n'; exit 1 ;; esac
fi

# Revalidate every path before the first mutation. Legacy paths are last in the
# array so they cannot be removed before current app state.
for target in "${targets[@]}"; do
  if check_target "$target"; then
    :
  else
    result=$?
    [[ $result -eq 2 ]] || exit "$result"
  fi
done
for target in "${targets[@]}"; do
  if check_target "$target"; then
    printf '  removing: %s\n' "$target"
    rm -rf -- "$target"
  else
    result=$?
    [[ $result -eq 2 ]] || exit "$result"
  fi
done
printf 'Removal complete. No elevation or system paths were used.\n'
