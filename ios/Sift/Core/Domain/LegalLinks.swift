import Foundation

/// The one place the published legal URLs and support address are defined.
///
/// These were previously string literals scattered through `SettingsView`, which meant
/// changing the domain was an exercise in grepping and hoping. App Review checks that these
/// resolve, so a stale or dead link is a rejection, not a cosmetic problem.
///
/// **Changing where the pages live is a one-line edit to `host` and `basePath` below.**
enum LegalLinks {
    /// Bare host, no scheme and no trailing slash.
    ///
    /// GitHub lowercases the owner name in Pages URLs, so this is not a typo for the
    /// repository owner's capitalisation.
    static let host = "tanjiro05-netizen.github.io"

    /// Project Pages sites are served under `/<repo>/` rather than at the root. Empty string
    /// for a root-served site or a custom domain.
    static let basePath = "/Finance-Planner"

    static let supportEmail = "JinbuJYG@proton.me"

    static var privacyPolicy: URL? {
        url(page: "privacy")
    }

    static var termsOfService: URL? {
        url(page: "terms")
    }

    /// Both pages must be reachable before external TestFlight review — Apple checks them.
    static var allPublishedPages: [URL] {
        [privacyPolicy, termsOfService].compactMap(\.self)
    }

    /// Trailing slash is deliberate: the pages are `privacy/index.html` and
    /// `terms/index.html`, which is what makes the extensionless URLs work on plain GitHub
    /// Pages. Requesting the directory directly avoids a redirect hop.
    private static func url(page: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "\(basePath)/\(page)/"
        return components.url
    }
}
