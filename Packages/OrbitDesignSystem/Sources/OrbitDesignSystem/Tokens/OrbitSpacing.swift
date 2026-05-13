import CoreGraphics

/// Orbit's spacing scale. Use exclusively — never hardcode pixel values inside
/// feature code. Generous spacing is part of the brand.
public enum OrbitSpacing {
    public static let xxs: CGFloat = 4
    public static let xs:  CGFloat = 8
    public static let sm:  CGFloat = 12
    public static let md:  CGFloat = 16
    public static let lg:  CGFloat = 20
    public static let xl:  CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    /// Default horizontal page padding.
    public static let pageHorizontal: CGFloat = md
    /// Default top inset for large-title screens.
    public static let pageTop: CGFloat = lg
}

public enum OrbitRadius {
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 28
    /// Pill radius — large enough to clip any height.
    public static let pill: CGFloat = 999
}

public enum OrbitHitTarget {
    /// Apple HIG minimum tappable area.
    public static let minimum: CGFloat = 44
}
