import Foundation

protocol OnboardingStateStoring: Sendable {
    func isComplete() -> Bool
    func setComplete(_ isComplete: Bool)
}

final class UserDefaultsOnboardingStateStore: OnboardingStateStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "sift.onboarding.isComplete"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func isComplete() -> Bool {
        defaults.bool(forKey: key)
    }

    func setComplete(_ isComplete: Bool) {
        defaults.set(isComplete, forKey: key)
    }
}

final class InMemoryOnboardingStateStore: OnboardingStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var complete: Bool

    init(isComplete: Bool = false) {
        complete = isComplete
    }

    func isComplete() -> Bool {
        lock.withLock { complete }
    }

    func setComplete(_ isComplete: Bool) {
        lock.withLock {
            complete = isComplete
        }
    }
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
