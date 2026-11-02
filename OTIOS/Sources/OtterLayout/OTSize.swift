import Foundation
import OtterCore
#if canImport(StretchKit)
import StretchKit
#endif

/// Port of `com.dynamic.otter.template.OTSize` and `ScreenAdapt.scaleFor`.
enum OTSize {
    case points(Float)
    case percent(Float)
    case auto
    case undefined

    static func create(_ raw: String, windowWidthPoints: Float) throws -> OTSize {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix(TemplateKey.OT_PX) {
            let number = String(value.dropLast(TemplateKey.OT_PX.count))
            return .points(adaptDpToPoints(try requireFloat(number), windowWidthPoints: windowWidthPoints))
        }
        if value.hasSuffix(TemplateKey.OT_PT) {
            let number = String(value.dropLast(TemplateKey.OT_PT.count))
            return .points(adaptPtToPoints(try requireFloat(number), windowWidthPoints: windowWidthPoints))
        }
        if value.hasSuffix(TemplateKey.OT_PE) {
            let number = String(value.dropLast(TemplateKey.OT_PE.count))
            return .percent(try requireFloat(number) / 100)
        }
        if value == TemplateKey.OT_WRAP_CONTENT {
            return .auto
        }
        if value == TemplateKey.OT_MATCH_PARENT {
            return .percent(1)
        }
        if !value.isEmpty {
            if let number = Float(value) {
                return .points(adaptDpToPoints(number, windowWidthPoints: windowWidthPoints))
            }
            // `ExpansionCenter.extensionSize` is not installed on iOS. Android
            // then returns `OTSize.Undefined`.
            return .undefined
        }
        return .undefined
    }

    var dimension: StretchKit.Dimension {
        switch self {
        case .points(let value):
            return .points(value)
        case .percent(let value):
            return .percent(value)
        case .auto:
            return .auto
        case .undefined:
            return .undefined
        }
    }

    /// `OTSize.valueInt`: points and percents truncate toward zero. Auto and
    /// undefined are 0. Percents are the 0...1 fraction, matching Kotlin.
    var valueInt: Int {
        switch self {
        case .points(let value), .percent(let value):
            return truncTowardZero(value)
        case .auto, .undefined:
            return 0
        }
    }

    var valueFloat: Float {
        switch self {
        case .points(let value), .percent(let value):
            return value
        case .auto, .undefined:
            return 0
        }
    }
}

/// JSON numbers are dp. Android `OTSize.adaptDpToPx` does
/// `round(dp * ScreenAdapt.scaleFor(windowWidthDp) * density)` and stores
/// `Dimension.Points`. UIKit layout is already in points, so density is 1 and
/// `windowWidthDp` is the viewport width in points:
/// `round(dp * ScreenAdapt.scaleFor(windowWidthPoints))`.
/// Do not multiply by `UIScreen.scale`; frames would be 2x/3x too big.
func adaptDpToPoints(_ dp: Float, windowWidthPoints: Float) -> Float {
    let density: Float = 1
    return Float(javaRoundToInt(dp * ScreenAdapt.scaleFor(windowWidthPoints) * density))
}

/// `OTSize.ptToPx`: `round(pt * (windowWidthDp / 375) * density)` with density 1.
/// This path does not clamp through `ScreenAdapt.scaleFor`.
func adaptPtToPoints(_ pt: Float, windowWidthPoints: Float) -> Float {
    let design = ScreenAdapt.DESIGN_WIDTH_DP
    let ratio: Float = windowWidthPoints > 0 && design > 0 ? windowWidthPoints / design : 1
    return Float(javaRoundToInt(pt * ratio))
}

/// `Float.roundToInt` / `java.lang.Math.round`: floor(x + 0.5).
func javaRoundToInt(_ value: Float) -> Int {
    if !value.isFinite {
        return 0
    }
    let rounded = floor(Double(value) + 0.5)
    if rounded >= Double(Int.max) {
        return Int.max
    }
    if rounded <= Double(Int.min) {
        return Int.min
    }
    return Int(rounded)
}

func truncTowardZero(_ value: Float) -> Int {
    if !value.isFinite {
        return 0
    }
    if value >= Float(Int.max) {
        return Int.max
    }
    if value <= Float(Int.min) {
        return Int.min
    }
    return Int(value)
}

private func requireFloat(_ text: String) throws -> Float {
    guard let number = Float(text) else {
        throw OTLayoutError("size is not a number: \(text)")
    }
    return number
}
