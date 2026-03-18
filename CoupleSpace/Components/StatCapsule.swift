import SwiftUI

struct StatCapsule: View {
    let title: String
    let value: String
    let note: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tint)

            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.title)

                Text(note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
    }
}
