import SwiftUI

struct WeeklyPlanCard: View {
    let item: WeeklyPlanItem
    var isHighlighted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.dayText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.tint)

                Text(item.timeText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.subtitle)
            }
            .frame(width: 88, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text(item.note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .stroke(
                    isHighlighted ? AppTheme.Colors.tint.opacity(0.28) : .clear,
                    lineWidth: 1.5
                )
        }
        .shadow(
            color: isHighlighted ? AppTheme.Colors.tint.opacity(0.12) : .clear,
            radius: 14,
            x: 0,
            y: 8
        )
    }
}
