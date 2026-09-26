#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/coretend-install-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
source_app="$test_root/source/CoreTend.app"
destination="$test_root/home/Applications"
if (($#)); then
  [[ $# -eq 1 ]] || { printf 'Usage: %s [CoreTend.app]\n' "$0" >&2; exit 64; }
  source_app="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
  [[ ! -L "$source_app" && -d "$source_app" ]] || { printf 'Package app is unavailable or symlinked.\n' >&2; exit 1; }
else
  mkdir -p "$source_app/Contents/MacOS"
  cat > "$source_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CoreTendApp</string>
<key>CFBundleIdentifier</key><string>local.coretend.install-test</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
  cat > "$source_app/Contents/MacOS/CoreTendApp" <<'APP'
#!/bin/sh
exit 0
APP
  chmod +x "$source_app/Contents/MacOS/CoreTendApp"
fi
mkdir -p "$destination"
bash "$repo_root/Scripts/install_local.sh" --app "$source_app" --destination "$destination"
installed="$destination/CoreTend.app"
test -x "$installed/Contents/MacOS/CoreTendApp"
cmp "$source_app/Contents/Info.plist" "$installed/Contents/Info.plist"
if bash "$repo_root/Scripts/install_local.sh" --app "$source_app" --destination "$destination"; then
  printf 'Installer unexpectedly replaced an existing app bundle.\n' >&2
  exit 1
fi
cmp "$source_app/Contents/Info.plist" "$installed/Contents/Info.plist"
symlink_destination="$test_root/symlink-applications"
ln -s "$destination" "$symlink_destination"
if bash "$repo_root/Scripts/install_local.sh" --app "$source_app" --destination "$symlink_destination"; then
  printf 'Installer unexpectedly accepted a symlink destination.\n' >&2
  exit 1
fi
symlink_source="$test_root/source-link.app"
ln -s "$source_app" "$symlink_source"
if bash "$repo_root/Scripts/install_local.sh" --app "$symlink_source" --destination "$test_root/home"; then
  printf 'Installer unexpectedly accepted a symlink source.\n' >&2
  exit 1
fi
test -d "$destination"
printf 'Install smoke test passed inside temporary HOME fixture; duplicate install refused.\n'
