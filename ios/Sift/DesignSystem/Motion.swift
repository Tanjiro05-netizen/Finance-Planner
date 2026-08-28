import SwiftUI

enum Motion {
    static let gentle = Animation.smooth(duration: 0.35)
    static let sheet = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let glassMorph = Animation.bouncy(duration: 0.45, extraBounce: 0.06)

    static let snappy = Animation.snappy(duration: 0.24)
    /// Damping raised from 0.70: press feedback that overshoots reads as toy-like. A
    /// button should settle, not bounce.
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.85)

    /// Was 0.60s. UI animation that the eye is waiting on belongs under ~300ms — at 600ms
    /// a counting balance stops reading as polish and starts reading as lag, and it delays
    /// the number the person opened the app to see.
    static let count = Animation.smooth(duration: 0.25)
    static let staggerStep = 0.04

    static let sheenPeriod: TimeInterval = 8.0
    static let scanSpin = Animation.linear(duration: 2.4).repeatForever(autoreverses: false)

    static func reduced(_ animation: Animation, reduceMotion: Bool, fallback: Animation? = nil) -> Animation? {
        reduceMotion ? fallback : animation
    }

    static func staggered(_ animation: Animation = gentle, index: Int, reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else {
            return nil
        }

        return animation.delay(Double(min(index, 8)) * staggerStep)
    }

    static func stepTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing))
    }

    static func rowTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
}
