import Foundation

/// The one network request CoreTend makes besides its own Sparkle update (decision 0007): reading
/// an app's own declared HTTPS appcast, only when the person clicks "Check for updates". No cookie,
/// no cache, nothing about the person; at most 2 MB, 15 seconds.
enum AppUpdateFeedFetcher {
    static func fetch(_ url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else { throw URLError(.unsupportedURL) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.httpAdditionalHeaders = ["User-Agent": "CoreTend"]
        let (data, response) = try await URLSession(configuration: configuration).data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 2_000_000 else { throw URLError(.badServerResponse) }
        return data
    }
}
