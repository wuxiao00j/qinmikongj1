import SwiftUI

struct SettingsItemRow: View {
    let item: SettingsItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.title)

                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.subtitle.opacity(0.7))
        }
        .padding(.vertical, 14)
    }
}
