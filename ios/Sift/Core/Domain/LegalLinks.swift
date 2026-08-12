import Foundation

/// The one place the published legal URLs and support address are defined.
///
/// These were previously string literals scattered through `SettingsView`, which meant
/// changing the domain was an exercise in grepping and hoping. App Review checks that these
/// resolve, so a stale or dead link is a rejection, not a cosmetic problem.
///
/// **Changing the domain is a one-line edit to `host` below.**
enum LegalLinks {
    /// Bare host, no scheme and no trailing slash.
    static let host = "sift.app"

    static let supportEmail = "support@sift.app"

    static var privacyPolicy: URL? {
        url(path: "privacy")
    }

    static var termsOfService: URL? {
        url(path: "terms")
    }

    /// Both pages must be reachable before external TestFlight review — Apple checks them.
    static var allPublishedPages: [URL] {
        [privacyPolicy, termsOfService].compactMap(\.self)
    }

    private static func url(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/\(path)"
        return components.url
    }
}
