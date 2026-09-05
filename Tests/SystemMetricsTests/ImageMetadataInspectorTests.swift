// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
@testable import SystemMetrics

/// All fixtures are generated programmatically here — no binary sample images
/// are committed to the repository, and nothing personal is ever read.
private enum Fixture {
    static func cgImage() -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return ctx.makeImage()!
    }

    /// Writes an image carrying `properties`. Returns `nil` when the platform
    /// cannot encode `type` (e.g. HEIC on a host without an HEVC encoder) so
    /// callers can skip rather than fail.
    static func write(_ properties: [CFString: Any], type: UTType = .jpeg, ext: String = "jpg") -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-\(UUID().uuidString).\(ext)")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage(), properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }

    static func writeRaw(_ data: Data, ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-\(UUID().uuidString).\(ext)")
        try! data.write(to: url)
        return url
    }

    static func remove(_ url: URL?) { if let url { try? FileManager.default.removeItem(at: url) } }
}

@Suite("ImageMetadataInspector — clean image")
struct ImageMetadataInspectorCleanTests {
    @Test func imageWithNoRelevantMetadataReportsEveryCategoryNotDetected() throws {
        let url = try #require(Fixture.write([:]))
        defer { Fixture.remove(url) }

        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.status == .inspected)
        #expect(inspection.formatIdentifier == "public.jpeg")
        #expect(inspection.presentCount == 0)
        #expect(inspection.unavailableCount == 0)
        #expect(inspection.preciseLocation == nil)
        // Every category is represented, and none is "present".
        #expect(inspection.findings.map(\.category) == ImageMetadataCategory.orderedForDisplay)
        for finding in inspection.findings {
            #expect(finding.field.presence == .notDetected, "\(finding.category) should be notDetected")
        }
    }

    @Test func notDetectedIsNeverReportedAsAnEmptyOrSafeResult() throws {
        // A clean image must still enumerate all categories — the caller
        // needs "not detected", not an absence it could read as "safe".
        let url = try #require(Fixture.write([:]))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.findings.count == ImageMetadataCategory.allCases.count)
    }
}

@Suite("ImageMetadataInspector — EXIF / TIFF fields")
struct ImageMetadataInspectorFieldTests {
    @Test func captureDateIsDetectedAndItsValueSurfaced() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2021:07:04 09:15:30",
            ],
        ]))
        defer { Fixture.remove(url) }
        let field = try #require(ImageMetadataInspector.inspect(fileURL: url).field(.captureDate))
        #expect(field.presence == .present)
        #expect(field.displayValue?.contains("2021") == true)
    }

    @Test func makeModelAndSoftwareAreDetectedWithValues() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "TestCam Industries",
                kCGImagePropertyTIFFModel: "TC-1000",
                kCGImagePropertyTIFFSoftware: "CoreTendUnitTest 1.0",
            ],
        ]))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.field(.cameraMake)?.displayValue == "TestCam Industries")
        #expect(inspection.field(.cameraModel)?.displayValue == "TC-1000")
        #expect(inspection.field(.software)?.displayValue == "CoreTendUnitTest 1.0")
        #expect(inspection.presentMetadataBlocks.contains("TIFF"))
    }

    @Test func authorCopyrightAndDescriptionAreDetectedFromIPTC() throws {
        // ImageIO's JPEG encoder stores authorship/description in IPTC (and
        // hands By-line back as an array) — the inspector must resolve all
        // three to a value regardless of which block they landed in.
        let url = try #require(Fixture.write([
            kCGImagePropertyIPTCDictionary: [
                kCGImagePropertyIPTCByline: "A. Photographer",
                kCGImagePropertyIPTCCopyrightNotice: "(c) 2021 A. Photographer",
                kCGImagePropertyIPTCCaptionAbstract: "Back garden, afternoon",
            ],
        ]))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.field(.artist)?.displayValue == "A. Photographer")
        #expect(inspection.field(.copyright)?.presence == .present)
        #expect(inspection.field(.description)?.displayValue == "Back garden, afternoon")
        #expect(inspection.presentMetadataBlocks.contains("IPTC"))
    }

    @Test func authorAndCopyrightAreDetectedFromTIFFTagsInATIFFFile() throws {
        // A real TIFF preserves IFD0 Artist/Copyright verbatim.
        let url = try #require(Fixture.write([
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFArtist: "A. Photographer",
                kCGImagePropertyTIFFCopyright: "(c) 2021 A. Photographer",
            ],
        ], type: .tiff, ext: "tiff"))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.field(.artist)?.displayValue == "A. Photographer")
        #expect(inspection.field(.copyright)?.displayValue == "(c) 2021 A. Photographer")
    }

    @Test func keywordArraysAreJoinedIntoASingleDisplayValue() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyIPTCDictionary: [
                kCGImagePropertyIPTCKeywords: ["holiday", "family", "beach"],
            ],
        ]))
        defer { Fixture.remove(url) }
        let field = try #require(ImageMetadataInspector.inspect(fileURL: url).field(.keywords))
        #expect(field.presence == .present)
        #expect(field.displayValue == "holiday, family, beach")
    }

    @Test func deviceSerialNumberIsDetected() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyExifAuxDictionary: [
                kCGImagePropertyExifAuxSerialNumber: "SN-ABC-123456",
            ],
        ]))
        defer { Fixture.remove(url) }
        #expect(ImageMetadataInspector.inspect(fileURL: url).field(.serialNumber)?.displayValue == "SN-ABC-123456")
    }

    @Test func emptyStringValueIsTreatedAsNotDetectedNotAPresentBlank() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "   "],
        ]))
        defer { Fixture.remove(url) }
        // The key is written but carries only whitespace: not a real value.
        #expect(ImageMetadataInspector.inspect(fileURL: url).field(.artist)?.presence == .notDetected)
    }

    @Test func lensModelIsDetectedFromExifAux() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyExifAuxDictionary: [
                kCGImagePropertyExifAuxLensModel: "TC 24-70mm f/2.8",
            ],
        ]))
        defer { Fixture.remove(url) }
        #expect(ImageMetadataInspector.inspect(fileURL: url).field(.lensModel)?.presence == .present)
    }
}

@Suite("ImageMetadataInspector — GPS")
struct ImageMetadataInspectorGPSTests {
    @Test func gpsCoordinatesAreDetectedAndSignedCorrectly() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.774900,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.419400,
                kCGImagePropertyGPSLongitudeRef: "W",
            ],
        ]))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.field(.location)?.presence == .present)
        #expect(inspection.field(.location)?.displayValue == nil, "coordinates are never inlined into the field")
        let precise = try #require(inspection.preciseLocation)
        #expect(abs(precise.latitude - 37.7749) < 0.0001)
        #expect(abs(precise.longitude - (-122.4194)) < 0.0001)
        #expect(precise.decimalDegrees == "37.774900, -122.419400")
        #expect(inspection.presentMetadataBlocks.contains("GPS"))
    }

    @Test func southernAndEasternHemisphereSignsAreApplied() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 33.8688, kCGImagePropertyGPSLatitudeRef: "S",
                kCGImagePropertyGPSLongitude: 151.2093, kCGImagePropertyGPSLongitudeRef: "E",
            ],
        ]))
        defer { Fixture.remove(url) }
        let precise = try #require(ImageMetadataInspector.inspect(fileURL: url).preciseLocation)
        #expect(precise.latitude < 0)
        #expect(precise.longitude > 0)
    }

    @Test func gpsBlockWithoutACoordinateIsStillPresentButHasNoPreciseLocation() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSTimeStamp: "09:15:30",
            ],
        ]))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        if inspection.presentMetadataBlocks.contains("GPS") {
            #expect(inspection.field(.location)?.presence == .present)
            #expect(inspection.preciseLocation == nil)
        } else {
            // Some encoders drop a GPS dict that carries no coordinate; then
            // "not detected" is the correct, honest answer.
            #expect(inspection.field(.location)?.presence == .notDetected)
        }
    }
}

@Suite("ImageMetadataInspector — formats")
struct ImageMetadataInspectorFormatTests {
    @Test func pngIsInspectedAndItsFormatIdentified() throws {
        let url = try #require(Fixture.write([:], type: .png, ext: "png"))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.status == .inspected)
        #expect(inspection.formatIdentifier == "public.png")
    }

    @Test func pngCarryingGpsMetadataIsDetectedWhenTheEncoderPreservesIt() throws {
        let url = try #require(Fixture.write([
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 48.8584, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 2.2945, kCGImagePropertyGPSLongitudeRef: "E",
            ],
        ], type: .png, ext: "png"))
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.status == .inspected)
        // PNG metadata support via ImageIO varies by OS version; when the
        // block survives the round-trip it must be reported, and when it
        // does not the category must read "not detected" — never a crash or
        // a fabricated coordinate.
        if inspection.presentMetadataBlocks.contains("GPS") {
            #expect(inspection.field(.location)?.presence == .present)
        } else {
            #expect(inspection.field(.location)?.presence == .notDetected)
        }
    }

    @Test func heicIsInspectedWhenThePlatformCanEncodeIt() throws {
        guard let url = Fixture.write([
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "HeicCam"],
        ], type: .heic, ext: "heic") else {
            // No HEVC encoder on this host — documented limitation, not a failure.
            return
        }
        defer { Fixture.remove(url) }
        let inspection = ImageMetadataInspector.inspect(fileURL: url)
        #expect(inspection.status == .inspected)
        #expect(inspection.field(.cameraMake)?.presence == .present)
    }
}

@Suite("ImageMetadataInspector — failure and malformed paths")
struct ImageMetadataInspectorFailureTests {
    @Test func missingFileReportsFileMissingNotUnreadable() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pl-missing-\(UUID().uuidString).jpg")
        #expect(ImageMetadataInspector.inspect(fileURL: url).status == .fileMissing)
    }

    @Test func corruptImageDataIsNeverReportedAsInspected() {
        let url = Fixture.writeRaw(Data((0..<512).map { _ in UInt8.random(in: 0...255) }), ext: "jpg")
        defer { Fixture.remove(url) }
        let status = ImageMetadataInspector.inspect(fileURL: url).status
        if case .inspected = status { Issue.record("random bytes must not inspect as an image") }
    }

    @Test func aFileWithOnlyAJpegStartMarkerIsNeverReportedAsInspected() {
        // Just the SOI marker: no frame, no APPn segments. ImageIO cannot
        // form an image from this.
        let url = Fixture.writeRaw(Data([0xFF, 0xD8]), ext: "jpg")
        defer { Fixture.remove(url) }
        let status = ImageMetadataInspector.inspect(fileURL: url).status
        if case .inspected = status { Issue.record("a 2-byte fragment must not inspect cleanly") }
    }

    @Test func nonImageFileIsNotInspected() {
        let url = Fixture.writeRaw(Data("this is plain text, not an image".utf8), ext: "txt")
        defer { Fixture.remove(url) }
        let status = ImageMetadataInspector.inspect(fileURL: url).status
        if case .inspected = status { Issue.record("a text file must not inspect as an image") }
    }

    @Test func directoryUrlIsNotInspected() {
        let dir = FileManager.default.temporaryDirectory
        let status = ImageMetadataInspector.inspect(fileURL: dir).status
        if case .inspected = status { Issue.record("a directory must not inspect as an image") }
    }

    @Test func fileDisappearingBeforeInspectionYieldsFileMissing() throws {
        let url = try #require(Fixture.write([:]))
        try FileManager.default.removeItem(at: url)
        #expect(ImageMetadataInspector.inspect(fileURL: url).status == .fileMissing)
    }
}
