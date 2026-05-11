import SwiftUI

/// SF Pro typographic ramp. All ramps support Dynamic Type via
/// `.relativeTo` sizing — never hard-cap text size.
public enum OrbitTypography {
    /// 34pt — editorial screen titles. Use sparingly, one per screen.
    public static let largeTitle = Font.system(
        .largeTitle, design: .default, weight: .bold
    ).leading(.tight)

    /// 28pt — section titles in long-scroll layouts.
    public static let title = Font.system(
        .title, design: .default, weight: .semibold
    ).leading(.tight)

    /// 22pt — card titles.
    public static let title2 = Font.system(
        .title2, design: .default, weight: .semibold
    )

    /// 20pt — sub-section labels.
    public static let title3 = Font.system(
        .title3, design: .default, weight: .semibold
    )

    /// 17pt — body copy.
    public static let body = Font.system(.body, design: .default, weight: .regular)

    /// 17pt — emphasized body copy.
    public static let bodyEmphasized = Font.system(
        .body, design: .default, weight: .semibold
    )

    /// 15pt — secondary copy in dense lists.
    public static let callout = Font.system(.callout, design: .default, weight: .regular)

    /// 13pt — supporting metadata, timestamps.
    public static let footnote = Font.system(.footnote, design: .default, weight: .regular)

    /// 12pt — uppercase eyebrows, used very sparingly.
    public static let caption = Font.system(.caption, design: .default, weight: .medium)

    /// Monospaced numerics — for counts and timers that should not jitter.
    public static let monoNumeric = Font.system(.body, design: .monospaced, weight: .medium)
}
