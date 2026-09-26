import Foundation
import Darwin

public enum QuarantineState: Sendable, Equatable { case present, absent, unavailable }

public struct QuarantineReport: Sendable, Equatable {
    public let state: QuarantineState
    public let errorCode: Int32?
    public init(state: QuarantineState, errorCode: Int32? = nil) {
        self.state = state
        self.errorCode = errorCode
    }
}

public struct MacOSQuarantineInspector: Sendable {
    public init() {}

    public func inspect(at url: URL) -> QuarantineReport {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return QuarantineReport(state: .unavailable, errorCode: errno) }
        guard (info.st_mode & S_IFMT) == S_IFDIR else { return QuarantineReport(state: .unavailable) }
        let length = url.path.withCString { path in
            "com.apple.quarantine".withCString { name in
                getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)
            }
        }
        if length >= 0 { return QuarantineReport(state: .present) }
        if errno == ENOATTR { return QuarantineReport(state: .absent) }
        return QuarantineReport(state: .unavailable, errorCode: errno)
    }
}
