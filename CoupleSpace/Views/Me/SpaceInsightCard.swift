import SwiftUI

struct SpaceInsightCard: View {
    let item: SpaceInsight
    var minHeight: CGFloat = 0
    var fixedHeight: CGFloat? = nil
    var noteLineLimit: Int? = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.subtitle)

            Text(item.value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(item.note)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
                .lineLimit(noteLineLimit)
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: fixedHeight ?? minHeight,
            maxHeight: fixedHeight,
            alignment: .leading
        )
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
    }
}
