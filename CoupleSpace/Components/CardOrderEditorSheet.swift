import SwiftUI

struct CardOrderEditorSheet<Item: Identifiable & Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    @Binding var items: [Item]
    let onReset: () -> Void
    let titleForItem: (Item) -> String
    let subtitleForItem: (Item) -> String
    let symbolForItem: (Item) -> String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("拖动来调整顺序")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("可调整的卡片") {
                    ForEach(items) { item in
                        HStack(alignment: .cardTitleCenter, spacing: 12) {
                            AppIconBadge(
                                symbol: symbolForItem(item),
                                fill: AppTheme.Colors.softAccent.opacity(0.28),
                                size: 40,
                                cornerRadius: 12
                            )
                            .alignmentGuide(.cardTitleCenter) { dimensions in
                                dimensions[VerticalAlignment.center]
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(titleForItem(item))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.title)
                                    .alignmentGuide(.cardTitleCenter) { dimensions in
                                        dimensions[VerticalAlignment.center]
                                    }

                                Text(subtitleForItem(item))
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Colors.subtitle)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: move)
                }

                Section {
                    Button("恢复默认顺序") {
                        onReset()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(title)
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}
