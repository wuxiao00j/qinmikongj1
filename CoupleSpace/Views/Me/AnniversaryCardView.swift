import SwiftUI

struct AnniversaryCardView: View {
    let item: AnniversaryItem
    var isHighlighted: Bool = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppIconBadge(symbol: item.category.symbol, fill: AppTheme.Colors.softAccent.opacity(0.35))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    PageMetaPill(text: item.category.rawValue, systemImage: item.category.symbol)

                    Spacer(minLength: 0)

                    if onEdit != nil || onDelete != nil {
                        AnniversaryItemMenu(onEdit: onEdit, onDelete: onDelete)
                    }
                }

                Text(item.dateText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    PageMetaPill(text: item.relativeText)
                    PageMetaPill(text: item.nextReminderText, emphasis: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
            cornerRadius: AppTheme.CornerRadius.medium,
            borderColor: isHighlighted ? AppTheme.Colors.softAccent : AppTheme.Colors.cardStroke
        )
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

private struct AnniversaryItemMenu: View {
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        Menu {
            if let onEdit {
                Button("编辑", systemImage: "pencil", action: onEdit)
            }
            if let onDelete {
                Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.subtitle)
                .frame(width: 30, height: 30)
                .background(AppTheme.Colors.cardSurface(.tertiary))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
