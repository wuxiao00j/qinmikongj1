import SwiftUI

struct RitualCard: View {
    let item: RitualItem
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .cardTitleCenter, spacing: 12) {
                AppIconBadge(
                    symbol: item.kind.symbol,
                    fill: item.isCompleted
                        ? AppTheme.Colors.softAccentSecondary.opacity(0.34)
                        : AppTheme.Colors.softAccent.opacity(0.26),
                    size: 40,
                    cornerRadius: 12
                )
                .alignmentGuide(.cardTitleCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                        .alignmentGuide(.cardTitleCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }

                    Text(item.summaryText)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineLimit(3)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)

                RitualCardMenu(onEdit: onEdit, onDelete: onDelete)
            }

            HStack(spacing: AppTheme.Spacing.compact) {
                PageMetaPill(text: item.kind.label, systemImage: item.kind.symbol)
                PageMetaPill(text: "写于 \(item.createdDayText)", systemImage: "clock")
                if item.isCompleted {
                    PageMetaPill(text: "今天做到啦", systemImage: "checkmark.heart.fill", emphasis: true)
                }
            }

            Button(action: onToggleCompletion) {
                PageActionPill(
                    text: item.isCompleted ? "改回还在慢慢做" : "今天做到啦",
                    systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            item.isCompleted
                ? AppTheme.Colors.cardSurface(.tertiary)
                : AppTheme.Colors.cardSurface(.primary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}

struct AddRitualItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingItem: RitualItem?
    let onSave: (RitualItem) -> Void

    @State private var title: String
    @State private var kind: RitualKind
    @State private var note: String

    init(
        existingItem: RitualItem? = nil,
        onSave: @escaping (RitualItem) -> Void
    ) {
        self.existingItem = existingItem
        self.onSave = onSave
        _title = State(initialValue: existingItem?.title ?? "")
        _kind = State(initialValue: existingItem?.kind ?? .promise)
        _note = State(initialValue: existingItem?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("写下一条只属于你们的小默契")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("可以是一点慢慢养成的小习惯，也可以是一句想认真留住的小约定。不用像任务，只要先把它放进生活里。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("默契内容") {
                    TextField("比如：睡前说晚安 / 回家先抱一下", text: $title)

                    Picker("类型", selection: $kind) {
                        ForEach(RitualKind.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("补一句很短的说明（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(existingItem == nil ? "新增默契" : "编辑默契")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingItem == nil ? "保存" : "更新") {
                        onSave(
                            RitualItem(
                                id: existingItem?.id ?? UUID(),
                                title: normalizedTitle,
                                kind: kind,
                                isCompleted: existingItem?.isCompleted ?? false,
                                note: normalizedNote,
                                createdAt: existingItem?.createdAt ?? .now,
                                updatedAt: existingItem?.updatedAt,
                                createdByUserId: existingItem?.createdByUserId ?? AppDataDefaults.localUserId,
                                spaceId: existingItem?.spaceId ?? AppDataDefaults.localSpaceId,
                                syncStatus: existingItem?.syncStatus ?? .localOnly
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty
    }
}

private struct RitualCardMenu: View {
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
    }
}
