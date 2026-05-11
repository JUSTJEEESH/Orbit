import SwiftUI

/// In-app gallery of every design system primitive. Exposed in Debug builds
/// from the Settings → Developer menu so engineers and designers can audit
/// the system without running Previews.
public struct DesignSystemGallery: View {
    public init() {}

    public var body: some View {
        OrbitScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                    typographySection
                    colorSection
                    buttonSection
                    chipSection
                    cardSection
                    textFieldSection
                }
                .padding(.vertical, OrbitSpacing.xxl)
            }
        }
        .navigationTitle("Design System")
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Typography")
            Text("Large Title").font(OrbitTypography.largeTitle)
            Text("Title").font(OrbitTypography.title)
            Text("Title 2").font(OrbitTypography.title2)
            Text("Title 3").font(OrbitTypography.title3)
            Text("Body — the quick brown fox jumps over the lazy dog.")
                .font(OrbitTypography.body)
            Text("Body emphasized").font(OrbitTypography.bodyEmphasized)
            Text("Callout").font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
            Text("Footnote · 2 min ago").font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
            Text("CAPTION").font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Color")
            LazyVGrid(columns: [.init(.adaptive(minimum: 96), spacing: OrbitSpacing.sm)], spacing: OrbitSpacing.sm) {
                swatch("background", OrbitColor.background)
                swatch("surface", OrbitColor.surface)
                swatch("surfaceMuted", OrbitColor.surfaceMuted)
                swatch("accent", OrbitColor.accent)
                swatch("warm", OrbitColor.accentWarm)
                swatch("green", OrbitColor.accentGreen)
                swatch("red", OrbitColor.accentRed)
            }
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            RoundedRectangle(cornerRadius: OrbitRadius.sm)
                .fill(color)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: OrbitRadius.sm)
                        .stroke(OrbitColor.separator, lineWidth: 0.5)
                )
            Text(name)
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }

    private var buttonSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Buttons")
            OrbitButton("Capture memory", systemImage: "plus", style: .primary) {}
            OrbitButton("Cancel", style: .secondary) {}
            OrbitButton("Skip", style: .ghost) {}
            OrbitButton("Delete forever", systemImage: "trash", style: .destructive) {}
            OrbitButton("Get Orbit Pro", style: .primary, size: .large) {}
        }
    }

    private var chipSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Chips")
            HStack(spacing: OrbitSpacing.xs) {
                OrbitChip("Notes")
                OrbitChip("Travel", systemImage: "airplane", style: .accent)
                OrbitChip("Done", style: .success, isSelected: true)
                OrbitChip("Urgent", style: .danger)
            }
        }
    }

    private var cardSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Cards")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Renew passport before July trip")
                        .font(OrbitTypography.bodyEmphasized)
                    Text("Travel · suggested by Orbit")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
            OrbitCard(elevation: .lifted) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("This week")
                        .font(OrbitTypography.title3)
                    Text("12 memories · 3 unfinished tasks")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
    }

    @State private var sampleText = ""

    private var textFieldSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Input")
            OrbitTextField("Search memories", text: $sampleText, systemImage: "magnifyingglass")
            OrbitTextField("What's on your mind?", text: $sampleText, axis: .vertical)
        }
    }
}

#Preview("Design System — Dark") {
    NavigationStack { DesignSystemGallery() }
        .preferredColorScheme(.dark)
}

#Preview("Design System — Light") {
    NavigationStack { DesignSystemGallery() }
        .preferredColorScheme(.light)
}
