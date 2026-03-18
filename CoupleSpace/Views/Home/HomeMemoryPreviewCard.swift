import SwiftUI

struct HomeMemoryPreviewCard: View {
    let memory: MemoryTimelineEntry

    private var metaItems: [HomeMemoryMetaItem] {
        [
            HomeMemoryMetaItem(text: memory.category.rawValue, systemImage: memory.category.symbol),
            HomeMemoryMetaItem(text: memory.recordContextText, systemImage: "book.closed")
        ] + Array(memory.metaItems.prefix(2)).map {
            HomeMemoryMetaItem(text: $0.text, systemImage: $0.symbol)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MemoryPhotoThumbnail(
                entry: memory,
                width: 92,
                height: 104,
                cornerRadius: AppTheme.CornerRadius.medium
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("最近写下的一条生活记录")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)

                Text(memory.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text(memory.bodyExcerpt)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineLimit(3)
                    .lineSpacing(3)

                homeMemoryMetaRow(metaItems)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func homeMemoryMetaRow(_ items: [HomeMemoryMetaItem]) -> some View {
        WrappedPillStack(
            items: items.map {
                WrappedPillItem(text: $0.text, systemImage: $0.systemImage)
            }
        )
    }
}

private struct HomeMemoryMetaItem: Identifiable {
    let id = UUID()
    let text: String
    let systemImage: String
}
