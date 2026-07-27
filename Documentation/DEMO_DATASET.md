<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend Demo Dataset

The dataset is generated from scratch by `Scripts/prepare-demo-data.sh` under a
new temporary directory. It contains no copied structure or content.

| Folder | Generated files | Scenario |
|---|---|---|
| `Demo Workspace/Sample Documents` | `Project Notes.txt`, `Status Report.txt`, deterministic duplicate copies | large/old listing and duplicate detection |
| `Demo Workspace/Example Projects` | neutral cache/log/build files | Cleanup rule review |
| `Demo Workspace/Photos Demo` | generated solid-color PPM images | image enumeration without real photos |
| `Demo Workspace/Archive` | deterministic binary samples | Space Lens sizing |

Text is authored solely for demonstration and released under CC0-1.0. Binary
content is generated from fixed repeated byte patterns; images are generated
PPM color fields. File dates are set to documented fixed dates. No input is
read from the operator's home directory, clipboard, photo library, contacts,
cloud storage or browser profile.

The script prints only the generic dataset root label, never a user path.
Future captures must use the dedicated `CoreTend Demo` account or VM and must
show only this dataset. A scan result may be described as real only when the
application actually produced it from these files.
