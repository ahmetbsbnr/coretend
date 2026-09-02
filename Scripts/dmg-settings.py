# dmgbuild settings for the CoreTend installer volume.
#
# This file is the whole window layout. dmgbuild writes the .DS_Store directly
# through the ds_store/mac_alias libraries, so nothing here needs the Finder,
# AppleScript, an Automation/TCC grant, or a graphical session — it runs the
# same in a local shell, in a non-interactive shell, and in GitHub Actions.
#
# Geometry note: Finder counts from the top-left, the background artwork is
# drawn from the bottom-left. The icon centres below must stay in step with
# dmgAppX / dmgApplicationsX / dmgIconY in
# Resources/Brand/Sources/generate-brand-assets.swift, or the icons stop
# landing inside the wells drawn for them.

import os

app_path = os.environ["CORETEND_APP"]
background_path = os.environ["CORETEND_DMG_BACKGROUND"]
volume_icon = os.environ.get("CORETEND_VOLUME_ICON") or None

# Contents of the volume. Only these two are visible; the licence texts ship
# sealed inside the bundle, and the background lives in a hidden .background
# folder that dmgbuild creates itself.
files = [app_path]
symlinks = {"Applications": "/Applications"}

# 600x400 points, matching the artwork exactly. window_rect is
# ((x, y), (width, height)) with the origin at the top-left of the screen.
window_rect = ((200, 140), (600, 400))
background = background_path
icon_size = 104
text_size = 12
default_view = "icon-view"
show_icon_preview = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
label_pos = "bottom"
show_item_info = False

# No sidebar, no toolbar, no status bar, no path bar — the window is a single
# instruction and nothing else.
sidebar_width = 0
show_sidebar = False
show_pathbar = False
show_tab_view = False
show_toolbar = False
show_statusbar = False

icon_locations = {
    "CoreTend.app": (170, 215),
    "Applications": (430, 215),
}

if volume_icon:
    icon = volume_icon

# UDZO with maximum compression, matching what the release pipeline published
# before. HFS+ so the layout is readable on every supported macOS.
format = "UDZO"
compression_level = 9
filesystem = "HFS+"
hide_extension = ["CoreTend.app"]
