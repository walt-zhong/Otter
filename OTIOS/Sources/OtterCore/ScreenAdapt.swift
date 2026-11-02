import Foundation

public enum ScreenAdapt {
    public static let DESIGN_WIDTH_DP: Float = 375

    private static let MIN_SCALE: Float = 0.88
    private static let MAX_REFERENCE_DP: Float = 480

    public static func scaleFor(
        _ windowWidthDp: Float,
        designWidthDp: Float = DESIGN_WIDTH_DP
    ) -> Float {
        if windowWidthDp <= 0 || designWidthDp <= 0 {
            return 1
        }
        let basis = min(windowWidthDp, MAX_REFERENCE_DP)
        return max(basis / designWidthDp, MIN_SCALE)
    }
}
