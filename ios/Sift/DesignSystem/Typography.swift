import SwiftUI
import UIKit

/// The app is set in San Francisco.
///
/// This replaces three bundled families — Fraunces, Plus Jakarta Sans and IBM Plex Mono —
/// and the reasoning is worth keeping, because "use the system font" reads like giving up
/// and is not.
///
/// All three families are named in the published catalogues of typefaces that signal
/// machine-generated design, and Fraunces is in the hardcoded list of a working slop
/// detector. That alone would only be a reason to swap them for three different faces.
/// The stronger reasons are mechanical:
///
/// - San Francisco ships as a variable font with **dynamic optical sizing**: the system
///   interpolates each glyph for the exact point size and retunes tracking at every size.
///   That is precisely the machinery Fraunces was missing when every glyph in the app,
///   including the 54pt hero, was rendering the design drawn for 9pt body copy.
/// - It has **real tabular figures**, so `.monospacedDigit()` finally does something.
///   Fraunces ships no `tnum`, which made that modifier a silent no-op and left money
///   columns misaligned by up to 19pt.
/// - Dynamic Type, Increase Contrast, Bold Text and the accessibility sizes all work
///   without reimplementation. Apple's guidance is explicit that a custom face has to
///   redo that work itself.
/// - It removes 16 bundled font files, and with them an SIL OFL 1.1 obligation the app
///   was not meeting: the licence requires the copyright notice and licence text ship
///   with each copy, and no licence file was ever bundled.
///
/// The counter-argument is real and worth stating: Wise, Monzo and Robinhood all ship
/// brand type in product. But the shape they use is a characterful *display* face over a
/// quiet *interface* face — never one face doing both, and never a high-contrast serif
/// setting functional UI. If Sift wants a voice later, that is where it goes: one or two
/// display moments, not the whole interface.
extension Font {
    /// Screen titles. Large, tight, and genuinely at the top of the hierarchy — the old
    /// scale had `screenTitle` used 5 times against `siftBody`'s 103.
    static var screenTitle: Font {
        .system(.largeTitle, design: .default).weight(.bold)
    }

    /// Section and card headings.
    static var cardTitle: Font {
        .system(.title3, design: .default).weight(.semibold)
    }

    /// Grouped-list section headers. Sentence case, not tracked-out caps.
    static var sectionHeader: Font {
        .system(.subheadline, design: .default).weight(.semibold)
    }

    static var siftBody: Font {
        .system(.body, design: .default)
    }

    static var bodyEmphasis: Font {
        .system(.body, design: .default).weight(.semibold)
    }

    static var buttonLabel: Font {
        .system(.headline, design: .default)
    }

    /// Supporting labels and captions.
    ///
    /// Was IBM Plex Mono at 10pt in all-caps, which is two named tells at once: monospace
    /// worn as a costume for "technical" when it is not setting data, and a tracked-out
    /// caps label above every section. Mono is kept in this app for exactly one job —
    /// measured values — and this is not that job.
    static var siftLabel: Font {
        .system(.footnote, design: .default).weight(.medium)
    }

    static var cadence: Font {
        .system(.caption, design: .default)
    }

    /// The one legitimate use of monospace here: values a person may want to compare
    /// character by character, such as an account's last four digits.
    static var siftMono: Font {
        .system(.footnote, design: .monospaced)
    }
}

/// How prominent a figure is, so money has a hierarchy.
///
/// It did not before: `MoneyText` took a raw `CGFloat` and 24 of its 29 call sites used
/// the same 50pt default, which meant a subscription's price, a monthly total and the
/// headline safe-to-spend number all rendered identically. `Font.heroFigure` existed and
/// was used zero times, because the raw parameter bypassed the type scale entirely.
enum MoneyRole {
    /// The one number a screen exists to show.
    case hero
    /// A section's headline figure.
    case primary
    /// A figure inside a list row.
    case row
    /// A figure set inline with body text.
    case inline

    var size: CGFloat {
        switch self {
        case .hero: 40
        case .primary: 28
        case .row: 17
        case .inline: 15
        }
    }

    var weight: Font.Weight {
        switch self {
        case .hero, .primary: .bold
        case .row: .semibold
        case .inline: .regular
        }
    }

    /// The Dynamic Type style each role scales against, so large accessibility sizes still
    /// grow these figures rather than freezing them.
    var textStyle: Font.TextStyle {
        switch self {
        case .hero: .largeTitle
        case .primary: .title
        case .row: .body
        case .inline: .subheadline
        }
    }
}

struct MoneyTextParts: Equatable {
    let symbol: String
    let major: String
    let fractional: String?
    let suffix: String?

    var accessibilityText: String {
        [symbol + major + (fractional ?? ""), suffix].compactMap(\.self).joined()
    }
}

enum MoneyTextFormatter {
    static func parts(from value: String) -> MoneyTextParts {
        var working = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbol = working.hasPrefix("$") ? "$" : ""
        if !symbol.isEmpty {
            working.removeFirst()
        }

        let suffix: String?
        if let slashIndex = working.firstIndex(of: "/") {
            suffix = String(working[slashIndex...])
            working = String(working[..<slashIndex])
        } else {
            suffix = nil
        }

        let fractional: String?
        let major: String
        if let dotIndex = working.firstIndex(of: ".") {
            major = String(working[..<dotIndex])
            fractional = String(working[dotIndex...])
        } else {
            major = working
            fractional = nil
        }

        return MoneyTextParts(symbol: symbol, major: major, fractional: fractional, suffix: suffix)
    }
}

/// A currency figure, with the symbol and cents set smaller and raised.
///
/// The construction here is deliberately unchanged: the raised symbol, the fractional part
/// at 48% on a baseline offset, and `.contentTransition(.numericText(value:))` respecting
/// reduce-motion. That structure was right. What was wrong sat underneath it — a face with
/// no tabular figures, so `.monospacedDigit()` did nothing and an animating balance
/// re-flowed sideways as it counted. San Francisco has real tabular figures, so the same
/// modifier now does the job it was always asking for.
struct MoneyText: View {
    let value: String
    var size: CGFloat = MoneyRole.row.size
    var weight: Font.Weight = MoneyRole.row.weight
    var textStyle: Font.TextStyle = MoneyRole.row.textStyle
    var color: Color = Palette.ink
    var secondaryColor: Color = Palette.inkSoft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        value: String,
        role: MoneyRole,
        color: Color = Palette.ink,
        secondaryColor: Color = Palette.inkSoft
    ) {
        self.value = value
        size = role.size
        weight = role.weight
        textStyle = role.textStyle
        self.color = color
        self.secondaryColor = secondaryColor
    }

    /// Kept so call sites that genuinely need an arbitrary size — the component gallery,
    /// mostly — still compile. Prefer `role:`.
    init(
        value: String,
        size: CGFloat = MoneyRole.row.size,
        weight: Font.Weight = MoneyRole.row.weight,
        textStyle: Font.TextStyle = MoneyRole.row.textStyle,
        color: Color = Palette.ink,
        secondaryColor: Color = Palette.inkSoft
    ) {
        self.value = value
        self.size = size
        self.weight = weight
        self.textStyle = textStyle
        self.color = color
        self.secondaryColor = secondaryColor
    }

    private var parts: MoneyTextParts {
        MoneyTextFormatter.parts(from: value)
    }

    private var numericTransitionValue: Double {
        let digits = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(digits) ?? 0
    }

    private func font(scale: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size * scale, weight: weight, design: .default)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            if !parts.symbol.isEmpty {
                Text(parts.symbol)
                    .font(font(scale: 0.48, weight: weight))
                    .baselineOffset(size * 0.30)
                    .foregroundStyle(secondaryColor)
            }

            Text(parts.major)
                .font(font(scale: 1, weight: weight))
                .foregroundStyle(color)

            if let fractional = parts.fractional {
                Text(fractional)
                    .font(font(scale: 0.48, weight: weight))
                    .baselineOffset(size * 0.30)
                    .foregroundStyle(secondaryColor)
            }

            if let suffix = parts.suffix {
                Text(suffix)
                    .font(font(scale: 0.42, weight: .medium))
                    .baselineOffset(size * 0.24)
                    .foregroundStyle(secondaryColor)
            }
        }
        .monospacedDigit()
        .contentTransition(.numericText(value: numericTransitionValue))
        .animation(Motion.reduced(Motion.count, reduceMotion: reduceMotion), value: value)
        .accessibilityLabel(parts.accessibilityText)
    }
}
