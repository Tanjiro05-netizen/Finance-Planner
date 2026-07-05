import Foundation
import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor private var routeHandler: (@MainActor (DeepLink) -> Void)?

    init(center: UNUserNotificationCenter? = nil) {
        super.init()
        center?.delegate = self
    }

    @MainActor
    func setRouteHandler(_ handler: @escaping @MainActor (DeepLink) -> Void) {
        routeHandler = handler
    }

    @MainActor
    @discardableResult
    func route(userInfo: [AnyHashable: Any]) -> Bool {
        guard let deepLink = SiftNotificationPayload.deepLink(from: userInfo) else {
            return false
        }

        route(deepLink)
        return true
    }

    @MainActor
    private func route(_ deepLink: DeepLink) {
        routeHandler?(deepLink)
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let deepLink = SiftNotificationPayload.deepLink(
            from: response.notification.request.content.userInfo
        ) else {
            return
        }

        await route(deepLink)
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
