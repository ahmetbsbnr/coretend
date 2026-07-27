<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Uninstall CoreTend

## Simple graphical uninstall

1. Choose Quit CoreTend or press Command-Q.
2. Open Applications in Finder.
3. Move only `CoreTend.app` to the Trash.
4. Empty the Trash if and when you choose.

This removes the application but intentionally keeps preferences and local
activity data for a later reinstall.

## Optional data reset

CoreTend-owned data is documented in `DATA_LOCATIONS.md`. The supported
advanced removal command is `Scripts/uninstall.sh`; run it from a trusted
source checkout and review its dry-run output first. It targets only the
verified CoreTend bundle identifier and support directories. Legacy
pre-rename data is excluded unless the explicit `--include-legacy` option is
provided.

Never delete a generic `Application Support`, Preferences, Caches or Logs
directory. Reinstalling the same version keeps existing data unless the
optional reset is performed.
