<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Privacy Lab — image metadata inspection

First vertical of Privacy Lab. **Read-only**: it inspects the metadata
embedded in an image file the user explicitly selects, explains what each
category can reveal, and keeps everything on this Mac. It never modifies the
image, never writes a sanitized copy, and never scans a Photos Library.

## User path

1. Sidebar → **Privacy Lab** (system group).
2. **Choose Image…** (toolbar or empty-state button) → a standard
   `NSOpenPanel` restricted to `UTType.image`.
3. The file is inspected on a detached utility task (never on `MainActor`).
4. A concise **Summary** (counts, not a score), then a per-category list:
   Present / Not detected / Unavailable, each with a "why this can matter"
   explanation and — for scalar values — the embedded value itself.
5. **Clear** or **Choose a Different Image…** resets state; a slower earlier
   inspection can never overwrite a newer selection (generation token).

## Architecture

| Layer | Type | Role |
|---|---|---|
| Domain | `ImageMetadataInspector` / `ImageMetadataInspection` / `MetadataField` / `MetadataFinding` / `PreciseLocation` (`Sources/SystemMetrics/ImageMetadataInspector.swift`) | Pure, synchronous ImageIO read. No SwiftUI, no persistence, no subprocess, no network. |
| App service | `PrivacyLabService` / `PrivacyLabCatalog` / `PrivacyLabSummary` (`Sources/CoreTendApp/PrivacyLabService.swift`) | Off-main-actor hop, localized per-category explanations, honest count-based summary. |
| View model | `PrivacyLabViewModel` (`Sources/CoreTendApp/PrivacyLabView.swift`) | One inspection at a time; generation token drops stale async results; nothing persisted. |
| UI | `PrivacyLabView` | Design-system screen in the existing navigation. |

The raw `[String: Any]` ImageIO dictionary is never exposed to SwiftUI —
`ImageMetadataInspector` converts it to structured, testable values first.

### Native Apple APIs used

- `ImageIO` — `CGImageSourceCreateWithURL`, `CGImageSourceGetType`,
  `CGImageSourceGetCount`, `CGImageSourceCopyPropertiesAtIndex`
  (with `kCGImageSourceShouldCache: false`).
- `CGImageProperties` constants for TIFF / Exif / Exif Aux / GPS / IPTC.
- `UniformTypeIdentifiers` for the open-panel content-type filter.
- No pixel buffer is ever decoded — `CGImageSourceCreateImageAtIndex` is not
  called. Metadata is read without a full decode.

## Three states, never "safe"

`MetadataPresence` is `present` / `notDetected` / `unavailable(reason:)`.
There is deliberately no "clean" / "safe" case:

- **Present** — the field is embedded in the file.
- **Not detected** — no supported field for this category was found. This is
  *not* a statement that the image carries nothing sensitive.
- **Unavailable** — the inspection itself could not evaluate this category
  (e.g. the property dictionaries could not be read at all).

`PrivacyLabSummary` reports counts (`presentCount`, `unavailableCount`) and an
honest headline. **There is no privacy score.**

## Metadata coverage

| Category | Source keys (first match wins) |
|---|---|
| Location / GPS | GPS `Latitude`/`Longitude` (+ `LatitudeRef`/`LongitudeRef`) |
| Capture date & time | Exif `DateTimeOriginal`, Exif `DateTimeDigitized`, TIFF `DateTime` |
| Camera / device make | TIFF `Make` |
| Camera / device model | TIFF `Model` |
| Lens model | Exif `LensModel`, Exif Aux `LensModel` |
| Software / editor | TIFF `Software` |
| Author / artist | TIFF `Artist`, IPTC `Byline` |
| Copyright | TIFF `Copyright`, IPTC `CopyrightNotice` |
| Description / comment | TIFF `ImageDescription`, IPTC `Caption/Abstract`, Exif `UserComment` |
| Keywords / tags | IPTC `Keywords` |
| Device / lens serial number | Exif Aux `SerialNumber`, Exif `BodySerialNumber`, Exif `LensSerialNumber` |
| Unique image identifier | Exif `ImageUniqueID` |

`presentMetadataBlocks` additionally lists which standard blocks (TIFF, Exif,
GPS, IPTC, …) are physically present, so the UI can disclose that a file
carries more than the named categories.

### GPS handling

- The main field shows only **Present / Not detected** — coordinates are
  never inlined into it.
- Exact coordinates (`PreciseLocation`, signed decimal degrees) are shown
  only behind an explicit opt-in toggle in the Location category's detail.
- No reverse geocoding. No network request. Coordinates are held in memory
  for the current inspection only and are never persisted or logged.
- A GPS block that exists but has no usable lat/long pair is still reported
  as **Present** (the file carries GPS metadata) with no coordinates.

## Supported formats (measured, not assumed)

Validated by `ImageMetadataInspectorTests` with programmatically generated
fixtures:

- **JPEG** — full coverage. Note ImageIO's JPEG encoder normalizes
  authorship/description into IPTC and returns By-line as an array; the
  inspector joins scalar arrays.
- **TIFF** — TIFF IFD0 tags (`Artist`, `Copyright`, `Make`, …) preserved
  verbatim.
- **PNG** — inspected and format-identified. Whether a GPS/Exif block
  survives a PNG round-trip depends on the OS ImageIO version; when it does
  not, the category reads **Not detected** (never a crash or a fabricated
  value).
- **HEIC/HEIF** — inspected when the host can encode HEIC (Apple Silicon).
  On a host without an HEVC encoder that fixture is skipped, not failed.
- **Corrupt / truncated / non-image / missing / directory** — reported as
  `unreadable` / `unsupported` / `fileMissing`, never `inspected`.

This vertical does **not** claim universal EXIF support for every image
format ImageIO can open.

## Privacy & safety guarantees

- **Local only.** No upload, no copy elsewhere, no network call, no
  telemetry, no analytics.
- **Not persisted by default.** No GPS coordinates, filenames, filesystem
  paths, author names, comments, device identifiers, or free-form metadata
  values are written to the Store, the Timeline, activity history, logs, or
  analytics. `PrivacyLabViewModel` holds one inspection in memory and drops
  it on `clear()`. The chosen file name is shown in the content header only —
  never in the sidebar or any history surface.
- **Original image is never modified.** No `FileManager` write/trash/remove,
  no `CGImageDestination`, no in-place EXIF strip anywhere in the vertical.
- **Not a Safety surface.** No `AdvisorFinding` is constructed for any
  metadata fact, so Privacy Lab is not Recovery-Plan-eligible by
  construction (`RecoveryPlanService` is untouched and carries zero
  references to any Privacy Lab type). `SafetyCore.RiskLevel` is not used —
  a read-only metadata fact has no action to be dangerous, exactly as with
  APFS Intelligence.
- **Photos Library boundary.** Privacy Lab only reads a single file URL the
  user explicitly selects through `NSOpenPanel`. It never enumerates the
  Photos Library, never uses the Photos framework, and never modifies any
  library.

## Not implemented (and not claimed)

- **Sanitized-copy / metadata stripping.** Not built. The layering keeps a
  clean boundary for a future *Original → read → sanitized copy → verify →
  compare → preserve original* flow, but no mutation exists today, not even
  unwired. A future user-facing operation must prefer **create sanitized
  copy** over **modify original**.
- XMP packet parsing (only presence of an Apple Maker Note is noted).
- Batch / folder inspection.
- Per-format exhaustive tag dumps.
