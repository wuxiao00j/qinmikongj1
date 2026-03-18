import SwiftUI

enum AppTheme {
    enum CardSurfaceLevel {
        case primary
        case secondary
        case tertiary
    }

    enum Colors {
        static let tint = Color(red: 0.53, green: 0.42, blue: 0.42)
        static let pageBackground = Color(red: 0.972, green: 0.958, blue: 0.949)
        static let cardBackground = Color(red: 0.994, green: 0.989, blue: 0.984)
        static let secondaryCardBackground = Color(red: 0.978, green: 0.969, blue: 0.961)
        static let tertiaryCardBackground = Color(red: 0.988, green: 0.979, blue: 0.972)
        static let emphasizedTertiaryCardBackground = Color(red: 0.956, green: 0.928, blue: 0.916)
        static let title = Color(uiColor: .label)
        static let subtitle = Color(uiColor: .secondaryLabel)
        static let divider = Color(red: 0.40, green: 0.31, blue: 0.31).opacity(0.08)
        static let softAccent = Color(red: 0.89, green: 0.84, blue: 0.82)
        static let softAccentSecondary = Color(red: 0.96, green: 0.91, blue: 0.89)
        static let deepAccent = Color(red: 0.45, green: 0.33, blue: 0.35)
        static let homeBackgroundTop = Color(red: 0.99, green: 0.97, blue: 0.96)
        static let homeBackgroundBottom = Color(red: 0.96, green: 0.94, blue: 0.93)
        static let elevatedCardBackground = cardBackground
        static let cardStroke = Color(red: 0.94, green: 0.91, blue: 0.89)
        static let glow = Color(red: 0.95, green: 0.87, blue: 0.88)

        static func cardSurface(_ level: AppTheme.CardSurfaceLevel) -> Color {
            switch level {
            case .primary:
                return cardBackground
            case .secondary:
                return secondaryCardBackground
            case .tertiary:
                return tertiaryCardBackground
            }
        }

        static func cardSurfaceGradient(
            _ level: AppTheme.CardSurfaceLevel,
            accent: Color = AppTheme.Colors.softAccent
        ) -> LinearGradient {
            let accentOpacity: Double

            switch level {
            case .primary:
                accentOpacity = 0.18
            case .secondary:
                accentOpacity = 0.12
            case .tertiary:
                accentOpacity = 0.08
            }

            return LinearGradient(
                colors: [
                    cardSurface(level),
                    accent.opacity(accentOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func pillSurface(emphasis: Bool = false) -> Color {
            emphasis ? emphasizedTertiaryCardBackground : tertiaryCardBackground
        }

        static func statusTone(_ tone: StatusTone) -> Color {
            switch tone {
            case .softGreen:
                return Color(red: 0.73, green: 0.82, blue: 0.74)
            case .berryRose:
                return Color(red: 0.84, green: 0.69, blue: 0.74)
            case .warmApricot:
                return Color(red: 0.90, green: 0.78, blue: 0.66)
            case .mistBlue:
                return Color(red: 0.72, green: 0.79, blue: 0.84)
            case .powderPink:
                return Color(red: 0.89, green: 0.78, blue: 0.82)
            }
        }
    }

    enum Spacing {
        static let page: CGFloat = 20
        static let section: CGFloat = 18
        static let content: CGFloat = 14
        static let compact: CGFloat = 10
        static let hero: CGFloat = 24
        static let pageBlock: CGFloat = 22
        static let cardGroup: CGFloat = 12
    }

    enum CornerRadius {
        static let large: CGFloat = 22
        static let medium: CGFloat = 18
        static let small: CGFloat = 12
        static let hero: CGFloat = 30
        static let badge: CGFloat = 14
    }

    enum Shadow {
        static let cardColor = Color(red: 0.35, green: 0.24, blue: 0.26).opacity(0.10)
        static let cardRadius: CGFloat = 24
        static let cardYOffset: CGFloat = 12
    }
}

struct AppAtmosphereBackground: View {
    var primaryGlow: Color = AppTheme.Colors.glow.opacity(0.28)
    var secondaryGlow: Color = AppTheme.Colors.softAccent.opacity(0.22)
    var primarySize: CGFloat = 280
    var secondarySize: CGFloat = 240
    var primaryOffset: CGSize = CGSize(width: -120, height: -240)
    var secondaryOffset: CGSize = CGSize(width: 120, height: -60)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.homeBackgroundTop,
                    AppTheme.Colors.homeBackgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(primaryGlow)
                .frame(width: primarySize, height: primarySize)
                .blur(radius: 60)
                .offset(primaryOffset)

            Circle()
                .fill(secondaryGlow)
                .frame(width: secondarySize, height: secondarySize)
                .blur(radius: 50)
                .offset(secondaryOffset)
        }
    }
}
