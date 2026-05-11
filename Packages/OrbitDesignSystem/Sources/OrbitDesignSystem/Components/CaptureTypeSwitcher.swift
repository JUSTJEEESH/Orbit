import SwiftUI
import OrbitKit

public struct CaptureTypeSwitcher: View {
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        case text, voice, photo, link

        public var title: String {
            switch self {
            case .text:  return "Note"
            case .voice: return "Voice"
            case .photo: return "Photo"
            case .link:  return "Link"
            }
        }

        public var systemImage: String {
            switch self {
            case .text:  return "text.alignleft"
            case .voice: return "mic.fill"
            case .photo: return "photo"
            case .link:  return "link"
            }
        }
    }

    @Binding private var selection: Kind
    @Namespace private var namespace

    public init(selection: Binding<Kind>) {
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Kind.allCases, id: \.self) { kind in
                Button {
                    Haptics.play(.selection)
                    withAnimation(OrbitMotion.snap) { selection = kind }
                } label: {
                    HStack(spacing: OrbitSpacing.xxs) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(kind.title)
                            .font(OrbitTypography.callout.weight(.semibold))
                    }
                    .padding(.horizontal, OrbitSpacing.md)
                    .padding(.vertical, OrbitSpacing.xs)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selection == kind ? OrbitColor.textInverted : OrbitColor.textSecondary)
                    .background {
                        if selection == kind {
                            RoundedRectangle(cornerRadius: OrbitRadius.md)
                                .fill(OrbitColor.textPrimary)
                                .matchedGeometryEffect(id: "switcher", in: namespace)
                        }
                    }
                    .contentShape(.rect(cornerRadius: OrbitRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.md))
    }
}
