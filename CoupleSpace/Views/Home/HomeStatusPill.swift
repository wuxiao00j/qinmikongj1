import SwiftUI

struct HomeStatusPill: View {
    let status: DailyStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.Colors.statusTone(status.tone).opacity(0.24))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .fill(AppTheme.Colors.statusTone(status.tone))
                            .frame(width: 5, height: 5)
                    )

                Text(status.personName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.subtitle)

                Spacer(minLength: 0)

                Text("此刻")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.softAccent.opacity(0.5))
                    .clipShape(Capsule())
            }

            Text(status.mood)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.secondaryCardBackground,
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}
