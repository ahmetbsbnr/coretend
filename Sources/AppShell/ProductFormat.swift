import Foundation

public enum ProductFormat {
    /// A file size in the app's language ("58,54 Go" in French, "58.54 GB" in English), whatever
    /// the system locale is.
    /// A count in the app's language ("18 000" in French, "18,000" in English).
    public static func count(_ value: Int, french: Bool) -> String {
        value.formatted(.number.locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    /// A number of items with its noun agreed ("1 élément", "0 élément", "3 éléments"; "1 item").
    public static func items(_ value: Int, french: Bool) -> String {
        let number = count(value, french: french)
        if french { return "\(number) \(value > 1 ? "éléments" : "élément")" }
        return "\(number) \(value == 1 ? "item" : "items")"
    }

    /// The French plural mark of a past participle agreeing with `value` ("déplacé" + "s").
    public static func frenchPlural(_ value: Int) -> String { value > 1 ? "s" : "" }

    /// A memory capacity in the app's language ("16 Go" / "16 GB").
    public static func memory(_ bytes: Int64, french: Bool) -> String {
        bytes.formatted(.byteCount(style: .memory).locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    /// The unit written under a count of files read ("fichiers examinés").
    public static func filesExamined(_ value: Int, french: Bool) -> String {
        if french { return value == 1 ? "fichier examiné" : "fichiers examinés" }
        return value == 1 ? "file examined" : "files examined"
    }

    /// A measured decimal with two fractional digits in the app's language.
    public static func decimal(_ value: Double, french: Bool) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    /// A reading timestamp using the same compact date as the product's measurements.
    public static func timestamp(_ date: Date, french: Bool) -> String {
        date.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    public static func bytes(_ count: Int64, french: Bool) -> String {
        count.formatted(.byteCount(style: .file).locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }
}

/// How much of a volume is used and free, for the soil band of the Overview. Built only from
/// measured, consistent values: anything unknown or impossible draws no soil rather than a guess.
public struct SoilFractions: Equatable, Sendable {
    public let used: Double
    public let free: Double

    public init?(free: Int64?, total: Int64?) {
        guard let free, let total, total > 0, free >= 0, free <= total else { return nil }
        self.free = Double(free) / Double(total)
        self.used = 1 - self.free
    }
}

/// Space that removing every copy but one would free: (copies − 1) × size, only for known sizes.
public enum DuplicateSpace {
    public static func recoverable(fileSize: Int64?, copies: Int) -> Int64? {
        guard let fileSize, fileSize >= 0, copies > 1 else { return nil }
        return fileSize * Int64(copies - 1)
    }
}

/// Groups measured files by the entry directly under a folder: a file there is its own plot, a
/// deeper file counts toward the subfolder that contains it. Only known sizes are counted.
public enum FolderPlots {
    public struct Plot: Equatable, Sendable {
        public let path: String
        public let bytes: Int64
        public let isFolder: Bool
        public let files: Int
    }

    public static func plots(files: [(path: String, bytes: Int64?)], under folder: String) -> [Plot] {
        let base = folder.hasSuffix("/") ? folder : folder + "/"
        var totals: [String: (bytes: Int64, folder: Bool, files: Int)] = [:]
        for file in files where file.path.hasPrefix(base) {
            let rest = file.path.dropFirst(base.count)
            guard let first = rest.split(separator: "/", omittingEmptySubsequences: true).first else { continue }
            let isFolder = rest.contains("/")
            let key = base + first
            let current = totals[key] ?? (0, isFolder, 0)
            totals[key] = (current.bytes + max(file.bytes ?? 0, 0), current.folder || isFolder, current.files + 1)
        }
        return totals.map { Plot(path: $0.key, bytes: $0.value.bytes, isFolder: $0.value.folder, files: $0.value.files) }
            .sorted { $0.bytes == $1.bytes ? $0.path < $1.path : $0.bytes > $1.bytes }
    }
}
