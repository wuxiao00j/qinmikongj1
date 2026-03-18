import SwiftUI

extension VerticalAlignment {
    private enum CardTitleCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[VerticalAlignment.center]
        }
    }

    static let cardTitleCenter = VerticalAlignment(CardTitleCenter.self)
}

struct AppCardSurface: ViewModifier {
    let background: AnyShapeStyle
    let cornerRadius: CGFloat
    let borderColor: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(shape.fill(background))
            .clipShape(shape)
            .overlay(
                shape.stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.Shadow.cardColor,
                radius: AppTheme.Shadow.cardRadius,
                x: 0,
                y: AppTheme.Shadow.cardYOffset
            )
    }
}

extension View {
    func appCardSurface<S: ShapeStyle>(
        _ background: S,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        borderColor: Color = AppTheme.Colors.cardStroke
    ) -> some View {
        modifier(
            AppCardSurface(
                background: AnyShapeStyle(background),
                cornerRadius: cornerRadius,
                borderColor: borderColor
            )
        )
    }
}

struct AppIconBadge: View {
    let symbol: String
    var fill: Color = AppTheme.Colors.softAccent
    var foreground: Color = AppTheme.Colors.deepAccent
    var size: CGFloat = 44
    var cornerRadius: CGFloat = AppTheme.CornerRadius.badge

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
    }
}

struct PageSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
    }
}

struct PageHeroLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(AppTheme.Colors.deepAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.Colors.cardSurface(.tertiary))
        .clipShape(Capsule())
    }
}

struct PageStatTile: View {
    let title: String
    let value: String
    var minHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PageMetaPill: View {
    let text: String
    var systemImage: String? = nil
    var emphasis: Bool = false

    var body: some View {
        HStack(spacing: systemImage == nil ? 0 : 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }

            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(emphasis ? AppTheme.Colors.deepAccent : AppTheme.Colors.subtitle)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.Colors.pillSurface(emphasis: emphasis))
        .clipShape(Capsule())
    }
}

struct PageActionPill: View {
    let text: String
    var systemImage: String = "chevron.right"

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.footnote.weight(.medium))
                .lineLimit(1)

            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Colors.deepAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.Colors.cardSurface(.tertiary))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct PageCTAButton: View {
    let text: String
    var systemImage: String = "plus"
    var fill: Color = AppTheme.Colors.softAccent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(text)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Colors.title)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(AppTheme.Colors.cardSurfaceGradient(.tertiary, accent: fill))
        )
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(AppTheme.Colors.divider, lineWidth: 1)
        }
    }
}

struct AppFeatureCard<HeaderAccessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let accent: Color
    @ViewBuilder var headerAccessory: HeaderAccessory
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        accent: Color = AppTheme.Colors.softAccent,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.accent = accent
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        accent: Color = AppTheme.Colors.softAccent,
        @ViewBuilder content: () -> Content
    ) where HeaderAccessory == EmptyView {
        self.init(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            accent: accent,
            headerAccessory: { EmptyView() },
            content: content
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .cardTitleCenter, spacing: 14) {
                AppIconBadge(
                    symbol: symbol,
                    fill: accent.opacity(0.22),
                    foreground: AppTheme.Colors.deepAccent
                )
                .alignmentGuide(.cardTitleCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                        .alignmentGuide(.cardTitleCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                }

                Spacer(minLength: 12)

                headerAccessory
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: accent)
        )
    }
}

struct AppSectionCard<HeaderAction: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    @ViewBuilder var headerAction: HeaderAction
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        @ViewBuilder headerAction: () -> HeaderAction,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.headerAction = headerAction()
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        @ViewBuilder content: () -> Content
    ) where HeaderAction == EmptyView {
        self.init(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            headerAction: { EmptyView() },
            content: content
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.content) {
            HStack(alignment: .cardTitleCenter, spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.tint)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.softAccent.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .alignmentGuide(.cardTitleCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                        .alignmentGuide(.cardTitleCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                    }
                }

                Spacer(minLength: 12)

                headerAction
            }

            content
        }
        .padding(AppTheme.Spacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.primary))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                .stroke(AppTheme.Colors.divider, lineWidth: 1)
        )
    }
}
