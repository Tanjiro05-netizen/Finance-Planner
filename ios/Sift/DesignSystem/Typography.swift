import SwiftUI
import UIKit

enum SiftFontPostScriptName: String, CaseIterable, Sendable {
    case frauncesRegular = "Fraunces-9pt"
    case frauncesSemiBold = "Fraunces-9ptSemiBold"
    case frauncesBold = "Fraunces-9ptBold"
    case plusJakartaRegular = "PlusJakartaSans-Regular"
    case plusJakartaMedium = "PlusJakartaSans-Medium"
    case plusJakartaSemiBold = "PlusJakartaSans-SemiBold"
    case plusJakartaBold = "PlusJakartaSans-Bold"
    case ibmPlexMonoRegular = "IBMPlexMono-Regular"
    case ibmPlexMonoMedium = "IBMPlexMono-Medium"
    case ibmPlexMonoSemiBold = "IBMPlexMono-SemiBold"
    case ibmPlexMonoBold = "IBMPlexMono-Bold"

    @MainActor
    var isRegistered: Bool {
        UIFont(name: rawValue, size: 12) != nil
    }
}

enum SiftFontFamily: CaseIterable, Sendable {
    case fraunces
    case plusJakartaSans
    case ibmPlexMono

    var displayName: String {
        switch self {
        case .fraunces: "Fraunces"
        case .plusJakartaSans: "Plus Jakarta Sans"
        case .ibmPlexMono: "IBM Plex Mono"
        }
    }

    var requiredFaces: [SiftFontPostScriptName] {
        switch self {
        case .fraunces:
            [.frauncesRegular, .frauncesSemiBold, .frauncesBold]
        case .plusJakartaSans:
            [.plusJakartaRegular, .plusJakartaMedium, .plusJakartaSemiBold, .plusJakartaBold]
        case .ibmPlexMono:
            [.ibmPlexMonoRegular, .ibmPlexMonoMedium, .ibmPlexMonoSemiBold, .ibmPlexMonoBold]
        }
    }
}

extension Font {
    static var heroFigure: Font {
        .custom(SiftFontPostScriptName.frauncesRegular.rawValue, size: 54, relativeTo: .largeTitle)
    }

    static var screenTitle: Font {
        .custom(SiftFontPostScriptName.frauncesSemiBold.rawValue, size: 30, relativeTo: .title)
    }

    static var cardTitle: Font {
        .custom(SiftFontPostScriptName.frauncesSemiBold.rawValue, size: 20, relativeTo: .title3)
    }

    static var siftBody: Font {
        .custom(SiftFontPostScriptName.plusJakartaRegular.rawValue, size: 15, relativeTo: .body)
    }

    static var bodyEmphasis: Font {
        .custom(SiftFontPostScriptName.plusJakartaBold.rawValue, size: 15, relativeTo: .body)
    }

    static var buttonLabel: Font {
        .custom(SiftFontPostScriptName.plusJakartaBold.rawValue, size: 15, relativeTo: .headline)
    }

    static var siftLabel: Font {
        .custom(SiftFontPostScriptName.ibmPlexMonoMedium.rawValue, size: 10, relativeTo: .caption)
    }

    static var cadence: Font {
        .custom(SiftFontPostScriptName.ibmPlexMonoMedium.rawValue, size: 9, relativeTo: .caption2)
    }
}

struct MoneyTextParts: Equatable, Sendable {
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

struct MoneyText: View {
    let value: String
    var size: CGFloat = 50
    var color: Color = Palette.ink
    var secondaryColor: Color = Palette.inkSoft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var parts: MoneyTextParts {
        MoneyTextFormatter.parts(from: value)
    }

    private var numericTransitionValue: Double {
        let digits = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(digits) ?? 0
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            if !parts.symbol.isEmpty {
                Text(parts.symbol)
                    .font(.custom(SiftFontPostScriptName.frauncesRegular.rawValue, size: size * 0.48))
                    .baselineOffset(size * 0.30)
                    .foregroundStyle(secondaryColor)
            }

            Text(parts.major)
                .font(.custom(SiftFontPostScriptName.frauncesRegular.rawValue, size: size))
                .foregroundStyle(color)

            if let fractional = parts.fractional {
                Text(fractional)
                    .font(.custom(SiftFontPostScriptName.frauncesRegular.rawValue, size: size * 0.48))
                    .baselineOffset(size * 0.30)
                    .foregroundStyle(secondaryColor)
            }

            if let suffix = parts.suffix {
                Text(suffix)
                    .font(.custom(SiftFontPostScriptName.frauncesSemiBold.rawValue, size: size * 0.42))
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
