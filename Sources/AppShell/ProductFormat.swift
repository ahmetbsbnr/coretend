import Foundation

public enum ProductFormat {
    /// A file size in the app's language ("58,54 Go" in French, "58.54 GB" in English), whatever
    /// the system locale is.
    /// A count in the app's language ("18 000" in French, "18,000" in English).
    public static func count(_ value: Int, french: Bool) -> String {
        value.formatted(.number.locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    /// The unit written under a count of files read ("fichiers examinés").
    public static func filesExamined(_ value: Int, french: Bool) -> String {
        if french { return value == 1 ? "fichier examiné" : "fichiers examinés" }
        return value == 1 ? "file examined" : "files examined"
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
