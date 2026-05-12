import SwiftUI

/// `.scaledFont(...)` — a Dynamic-Type-aware version of
/// `.font(.system(size:weight:design:))`. The design size you pass in
/// becomes the *unscaled* baseline; iOS scales it up or down with the
/// user's accessibility text size, just like a built-in `.body` /
/// `.callout` / `.footnote` would.
///
/// Use this anywhere a pixel-exact design size matters (e.g., 14pt
/// labels paired with a 16pt icon) but the text still needs to grow
/// at Larger Text settings. For purely-semantic sizing, prefer the
/// `OrbitTypography` tokens.
public extension View {
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFontModifier(
            size: size,
            weight: weight,
            design: design,
            textStyle: textStyle
        ))
    }
}

private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let textStyle: Font.TextStyle

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, textStyle: Font.TextStyle) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
        self.textStyle = textStyle
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}
