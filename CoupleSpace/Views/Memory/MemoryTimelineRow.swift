import SwiftUI
import UIKit

struct MemoryTimelineRow: View {
    let entry: MemoryTimelineEntry
    var showsManagementMenu: Bool = true
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.monthDayText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)

                Text(entry.yearMonthText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.subtitle)
            }
            .frame(width: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    MemoryCategoryTag(category: entry.category)

                    PageMetaPill(text: entry.recordContextText, systemImage: "book")

                    Spacer(minLength: 0)

                    if showsManagementMenu {
                        MemoryEntryMenu(onEdit: onEdit, onDelete: onDelete)
                            .zIndex(1)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(entry.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(entry.bodyExcerpt)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(
                            entry.updatedAt.timeIntervalSince(entry.createdAt) > 60
                                ? "后来又补了一点当时的细节。"
                                : "那天的感觉被认真留在这里。"
                        )
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.deepAccent)
                            .lineSpacing(3)

                        if !entry.metaItems.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.compact) {
                                    ForEach(entry.metaItems) { item in
                                        PageMetaPill(text: item.text, systemImage: item.symbol)
                                    }
                                }
                                .padding(.vertical, 1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    MemoryPhotoThumbnail(entry: entry)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardSurface(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.elevatedCardBackground,
                        AppTheme.Colors.softAccent.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

struct MemoryEntryMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button("编辑", systemImage: "pencil", action: onEdit)
            Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.subtitle)
                .frame(width: 30, height: 30)
                .background(AppTheme.Colors.cardSurface(.tertiary))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct MemoryPhotoThumbnail: View {
    let entry: MemoryTimelineEntry
    var width: CGFloat = 102
    var height: CGFloat = 124
    var cornerRadius: CGFloat = AppTheme.CornerRadius.medium

    var body: some View {
        Group {
            if let image = MemoryPhotoStorage.uiImage(for: entry.photoFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.softAccent.opacity(0.75),
                                AppTheme.Colors.secondaryCardBackground
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.deepAccent)

                            Spacer(minLength: 0)

                            Text(entry.imageLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.deepAccent)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if entry.hasPhoto {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.36)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .font(.caption2.weight(.semibold))

                    Text(entry.monthDayText)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(Color.white.opacity(0.94))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }
}
