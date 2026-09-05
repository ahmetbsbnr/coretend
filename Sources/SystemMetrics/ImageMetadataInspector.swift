// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Privacy Lab's read-only image-metadata domain. Everything here is a pure
/// read: ImageIO's `CGImageSource` is asked only for its *property*
/// dictionaries — the pixel data is never decoded, nothing is written, no
/// subprocess is spawned, no network call is made. See
/// `Documentation/PRIVACY_LAB.md` for the product-level explanation of every
/// distinction drawn below (present vs. not-detected vs. unavailable, why GPS
/// is handled apart, what "supported" actually means per format).

// MARK: - Field presence

/// The three states Privacy Lab must always keep distinct. There is
/// deliberately no "safe" / "clean" case: the absence of a *supported* field
/// is `.notDetected`, never a statement that the image carries nothing
/// sensitive. `.unavailable` means the inspection itself could not read that
/// information — a genuinely different fact from "the field is not there".
public enum MetadataPresence: Sendable, Equatable {
    case present
    case notDetected
    case unavailable(reason: String)
}

/// One privacy-relevant metadata category and what the inspector found for
/// it. `displayValue` is an already-extracted, human-readable rendering of
/// the embedded value when one exists and is safe to show inline
/// (manufacturer, model, software, author, …). It is intentionally `nil`
/// for `.location` — precise coordinates are exposed only through
/// `ImageMetadataInspection.preciseLocation`, behind an explicit
/// disclosure — and `nil` whenever the value is present but not a
/// displayable scalar (a malformed or structurally unexpected value still
/// counts as `.present`: the data is in the file).
public struct MetadataField: Sendable, Equatable {
    public let presence: MetadataPresence
    public let displayValue: String?

    public init(presence: MetadataPresence, displayValue: String? = nil) {
        self.presence = presence
        self.displayValue = displayValue
    }

    static let notDetected = MetadataField(presence: .notDetected, displayValue: nil)
    static func unavailable(_ reason: String) -> MetadataField {
        MetadataField(presence: .unavailable(reason: reason), displayValue: nil)
    }
    static func present(_ value: String?) -> MetadataField {
        MetadataField(presence: .present, displayValue: value)
    }
}

// MARK: - Categories

/// The privacy-relevant categories Privacy Lab reports. Kept to fields
/// ImageIO exposes reliably across the formats CoreTend's deployment target
/// supports. `rawValue` is a stable identifier used for `Localizable.strings`
/// keys and test assertions — never shown to the user directly.
public enum ImageMetadataCategory: String, Sendable, CaseIterable {
    case location
    case captureDate
    case cameraMake
    case cameraModel
    case lensModel
    case software
    case artist
    case copyright
    case description
    case keywords
    case serialNumber
    case uniqueImageID

    /// Canonical display order — most privacy-consequential first.
    public static let orderedForDisplay: [ImageMetadataCategory] = [
        .location, .captureDate, .cameraMake, .cameraModel, .lensModel,
        .software, .artist, .copyright, .description, .keywords,
        .serialNumber, .uniqueImageID,
    ]
}

/// A category paired with the inspector's finding for it.
public struct MetadataFinding: Sendable, Equatable {
    public let category: ImageMetadataCategory
    public let field: MetadataField

    public init(category: ImageMetadataCategory, field: MetadataField) {
        self.category = category
        self.field = field
    }
}

// MARK: - Precise location (opt-in detail only)

/// Exact coordinates decoded from the GPS block. Held only in memory for the
/// lifetime of one inspection and surfaced only behind an explicit user
/// disclosure — never persisted, never logged, never reverse-geocoded, never
/// sent anywhere.
public struct PreciseLocation: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// `"37.774900, -122.419400"` — fixed 6-decimal decimal-degrees, no
    /// place name, `%f` formatting so a localized decimal comma never enters
    /// the value.
    public var decimalDegrees: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}

// MARK: - Inspection result

public struct ImageMetadataInspection: Sendable, Equatable {
    /// The outcome of *opening and reading* the file — distinct from what
    /// was found inside it.
    public enum Status: Sendable, Equatable {
        /// The file was opened as an image and its property dictionaries
        /// were read. Individual fields may still be `.notDetected` or
        /// `.unavailable`.
        case inspected
        /// ImageIO opened the file but it is not an image type this build
        /// can inspect, or it contains zero images.
        case unsupported(detail: String)
        /// The file exists but could not be opened as an image at all
        /// (truncated, corrupt, or not image data).
        case unreadable(reason: String)
        /// No file exists at the given URL.
        case fileMissing
    }

    public let status: Status
    /// Uniform Type Identifier ImageIO assigned the source (e.g.
    /// `"public.jpeg"`). Non-sensitive; `nil` when the type is unknown.
    public let formatIdentifier: String?
    /// Which standard metadata blocks are physically present in the file
    /// (`"TIFF"`, `"Exif"`, `"GPS"`, `"IPTC"`, …). Structural fact only — no
    /// values — for honest "there is more in here than the named categories"
    /// disclosure.
    public let presentMetadataBlocks: [String]
    /// Every category in `ImageMetadataCategory.orderedForDisplay`, in that
    /// order, when `status == .inspected`; empty otherwise.
    public let findings: [MetadataFinding]
    /// Exact coordinates, when a usable GPS position was decoded. Callers
    /// must treat this as sensitive: in-memory only.
    public let preciseLocation: PreciseLocation?

    public init(status: Status, formatIdentifier: String?, presentMetadataBlocks: [String],
                findings: [MetadataFinding], preciseLocation: PreciseLocation?) {
        self.status = status
        self.formatIdentifier = formatIdentifier
        self.presentMetadataBlocks = presentMetadataBlocks
        self.findings = findings
        self.preciseLocation = preciseLocation
    }

    public func field(_ category: ImageMetadataCategory) -> MetadataField? {
        findings.first { $0.category == category }?.field
    }

    /// Count of categories with an actually-embedded value.
    public var presentCount: Int {
        findings.filter { if case .present = $0.field.presence { return true } else { return false } }.count
    }

    /// Count of categories the inspection could not evaluate.
    public var unavailableCount: Int {
        findings.filter { if case .unavailable = $0.field.presence { return true } else { return false } }.count
    }
}

// MARK: - Inspector

/// Reads image metadata via ImageIO without decoding pixels. Every entry
/// point is a pure, synchronous read that takes an explicit file URL; the
/// caller runs it off the main actor (Privacy Lab uses a detached utility
/// task). No instance state, no caching.
public enum ImageMetadataInspector {

    /// Inspects the file at `fileURL`. Never throws — every failure mode is
    /// represented in `ImageMetadataInspection.Status`.
    public static func inspect(fileURL: URL) -> ImageMetadataInspection {
        func result(_ status: ImageMetadataInspection.Status,
                    format: String? = nil, blocks: [String] = [],
                    findings: [MetadataFinding] = [], location: PreciseLocation? = nil) -> ImageMetadataInspection {
            ImageMetadataInspection(status: status, formatIdentifier: format,
                                    presentMetadataBlocks: blocks, findings: findings,
                                    preciseLocation: location)
        }

        guard fileURL.isFileURL else {
            return result(.unreadable(reason: "not a file URL"))
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return result(.fileMissing)
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions) else {
            return result(.unreadable(reason: "ImageIO could not open the file as an image"))
        }

        let uti = CGImageSourceGetType(source) as String?
        guard CGImageSourceGetCount(source) > 0 else {
            return result(.unsupported(detail: "the file contains no inspectable image"), format: uti)
        }

        let propertyOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let raw = CGImageSourceCopyPropertiesAtIndex(source, 0, propertyOptions) as? [String: Any] else {
            // The image opened, but its property dictionaries could not be
            // read — every category is genuinely unevaluable, not "absent".
            let findings = ImageMetadataCategory.orderedForDisplay.map {
                MetadataFinding(category: $0, field: .unavailable("image properties could not be read"))
            }
            return result(.inspected, format: uti, findings: findings)
        }

        let tiff = raw[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exif = raw[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let exifAux = raw[kCGImagePropertyExifAuxDictionary as String] as? [String: Any]
        let gps = raw[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        let iptc = raw[kCGImagePropertyIPTCDictionary as String] as? [String: Any]

        let (locationField, precise) = resolveLocation(gps: gps)

        var findings: [MetadataFinding] = []
        for category in ImageMetadataCategory.orderedForDisplay {
            let field: MetadataField
            switch category {
            case .location:
                field = locationField
            case .captureDate:
                field = firstValue([(exif, kCGImagePropertyExifDateTimeOriginal as String),
                                    (exif, kCGImagePropertyExifDateTimeDigitized as String),
                                    (tiff, kCGImagePropertyTIFFDateTime as String)])
            case .cameraMake:
                field = firstValue([(tiff, kCGImagePropertyTIFFMake as String)])
            case .cameraModel:
                field = firstValue([(tiff, kCGImagePropertyTIFFModel as String)])
            case .lensModel:
                field = firstValue([(exif, kCGImagePropertyExifLensModel as String),
                                    (exifAux, kCGImagePropertyExifAuxLensModel as String)])
            case .software:
                field = firstValue([(tiff, kCGImagePropertyTIFFSoftware as String)])
            case .artist:
                field = firstValue([(tiff, kCGImagePropertyTIFFArtist as String),
                                    (iptc, kCGImagePropertyIPTCByline as String)])
            case .copyright:
                field = firstValue([(tiff, kCGImagePropertyTIFFCopyright as String),
                                    (iptc, kCGImagePropertyIPTCCopyrightNotice as String)])
            case .description:
                field = firstValue([(tiff, kCGImagePropertyTIFFImageDescription as String),
                                    (iptc, kCGImagePropertyIPTCCaptionAbstract as String),
                                    (exif, kCGImagePropertyExifUserComment as String)])
            case .keywords:
                field = keywordsValue(iptc)
            case .serialNumber:
                field = firstValue([(exifAux, kCGImagePropertyExifAuxSerialNumber as String),
                                    (exif, kCGImagePropertyExifBodySerialNumber as String),
                                    (exif, kCGImagePropertyExifLensSerialNumber as String)])
            case .uniqueImageID:
                field = firstValue([(exif, kCGImagePropertyExifImageUniqueID as String)])
            }
            findings.append(MetadataFinding(category: category, field: field))
        }

        return result(.inspected, format: uti, blocks: presentBlocks(raw),
                      findings: findings, location: precise)
    }

    // MARK: - Field extraction

    /// Walks an ordered list of `(dictionary, key)` candidates and returns
    /// the first that resolves. A present-but-unrenderable value is still
    /// `.present` (the data is in the file) with a `nil` `displayValue`.
    private static func firstValue(_ candidates: [(dict: [String: Any]?, key: String)]) -> MetadataField {
        for candidate in candidates {
            guard let dict = candidate.dict, let raw = dict[candidate.key] else { continue }
            return .present(displayString(from: raw))
        }
        return .notDetected
    }

    private static func keywordsValue(_ iptc: [String: Any]?) -> MetadataField {
        guard let iptc, let raw = iptc[kCGImagePropertyIPTCKeywords as String] else { return .notDetected }
        if let list = raw as? [Any] {
            let joined = list.compactMap { displayString(from: $0) }.joined(separator: ", ")
            return .present(joined.isEmpty ? nil : joined)
        }
        return .present(displayString(from: raw))
    }

    /// Best-effort scalar rendering. Joins arrays of scalars (ImageIO
    /// commonly hands back IPTC By-line and Keywords as arrays), and returns
    /// `nil` for dictionaries, empty strings, and binary noise — never a
    /// stringified dictionary.
    private static func displayString(from raw: Any) -> String? {
        switch raw {
        case let list as [Any]:
            let joined = list.compactMap { displayString(from: $0) }.joined(separator: ", ")
            return joined.isEmpty ? nil : joined
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        case let data as Data:
            // EXIF UserComment is frequently an 8-byte character-code prefix
            // followed by text. Decode only if the tail is valid UTF-8;
            // otherwise report nothing rather than mojibake.
            guard data.count > 8 else { return nil }
            let tail = data.suffix(from: data.index(data.startIndex, offsetBy: 8))
            guard let text = String(data: tail, encoding: .utf8) else { return nil }
            let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{0}")))
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }

    // MARK: - Location

    /// Resolves the GPS block into a coarse `.present`/`.notDetected` field
    /// plus, when a usable coordinate pair exists, exact coordinates for the
    /// opt-in disclosure. A GPS dictionary that exists but lacks a usable
    /// lat/long pair is still `.present` (the file carries GPS metadata)
    /// with no `preciseLocation`.
    private static func resolveLocation(gps: [String: Any]?) -> (MetadataField, PreciseLocation?) {
        guard let gps, !gps.isEmpty else { return (.notDetected, nil) }

        guard
            let lat = (gps[kCGImagePropertyGPSLatitude as String] as? NSNumber)?.doubleValue,
            let lon = (gps[kCGImagePropertyGPSLongitude as String] as? NSNumber)?.doubleValue,
            lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180
        else {
            return (MetadataField(presence: .present, displayValue: nil), nil)
        }

        let latRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String)?.uppercased()
        let lonRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String)?.uppercased()
        let signedLat = (latRef == "S" ? -1 : 1) * abs(lat)
        let signedLon = (lonRef == "W" ? -1 : 1) * abs(lon)

        return (MetadataField(presence: .present, displayValue: nil),
                PreciseLocation(latitude: signedLat, longitude: signedLon))
    }

    // MARK: - Structural

    private static func presentBlocks(_ raw: [String: Any]) -> [String] {
        var found: [String] = []
        let candidates: [(String, String)] = [
            (kCGImagePropertyTIFFDictionary as String, "TIFF"),
            (kCGImagePropertyExifDictionary as String, "Exif"),
            (kCGImagePropertyExifAuxDictionary as String, "Exif Aux"),
            (kCGImagePropertyGPSDictionary as String, "GPS"),
            (kCGImagePropertyIPTCDictionary as String, "IPTC"),
            (kCGImagePropertyGIFDictionary as String, "GIF"),
            (kCGImagePropertyPNGDictionary as String, "PNG"),
            (kCGImagePropertyJFIFDictionary as String, "JFIF"),
        ]
        for (key, label) in candidates where raw[key] is [String: Any] {
            found.append(label)
        }
        if raw[kCGImagePropertyMakerAppleDictionary as String] != nil {
            found.append("Apple Maker Note")
        }
        return found
    }
}
