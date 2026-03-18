import SwiftUI

struct DinnerSuggestionCard: View {
    let item: TonightDinnerOption
    let onChoose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .cardTitleCenter, spacing: 10) {
                AppIconBadge(
                    symbol: "fork.knife",
                    fill: AppTheme.Colors.softAccent.opacity(0.28),
                    size: 40,
                    cornerRadius: 12
                )
                .alignmentGuide(.cardTitleCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

                VStack(alignment: .leading, spacing: 4) {
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

                DinnerCardMenu(onEdit: onEdit, onDelete: onDelete)
            }

            HStack(spacing: AppTheme.Spacing.compact) {
                PageMetaPill(text: item.status.label, systemImage: "sparkles")
                PageMetaPill(text: "写于 \(item.createdDayText)", systemImage: "clock")
            }

            Button(action: onChoose) {
                PageCTAButton(text: "今晚就吃这个", systemImage: "checkmark")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.primary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}

struct ChosenDinnerCard: View {
    let item: TonightDinnerOption
    let partnerName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .cardTitleCenter, spacing: 12) {
                AppIconBadge(
                    symbol: "fork.knife.circle.fill",
                    fill: AppTheme.Colors.softAccentSecondary.opacity(0.4),
                    size: 44,
                    cornerRadius: 14
                )
                .alignmentGuide(.cardTitleCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("今晚已经决定")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.deepAccent)

                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                        .alignmentGuide(.cardTitleCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }

                    Text(chosenNoteText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }

                Spacer(minLength: 0)

                DinnerCardMenu(onEdit: onEdit, onDelete: onDelete)
            }

            HStack(spacing: AppTheme.Spacing.compact) {
                PageMetaPill(text: item.status.label, systemImage: "heart.fill", emphasis: true)
                if let decidedDayText = item.decidedDayText {
                    PageMetaPill(text: "\(decidedDayText) 定下", systemImage: "clock")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.secondary, accent: AppTheme.Colors.softAccentSecondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private var chosenNoteText: String {
        let note = item.detailText
        if !note.isEmpty {
            return note
        }

        return "这个小决定已经先替你们收好了，等晚上和 \(partnerName) 见面时就不用再重新想一遍。"
    }
}

struct AddDinnerOptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingItem: TonightDinnerOption?
    let onSave: (TonightDinnerOption) -> Void

    @State private var title: String
    @State private var note: String

    init(
        existingItem: TonightDinnerOption? = nil,
        onSave: @escaping (TonightDinnerOption) -> Void
    ) {
        self.existingItem = existingItem
        self.onSave = onSave
        _title = State(initialValue: existingItem?.title ?? "")
        _note = State(initialValue: existingItem?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("先留一个今晚想吃的选项")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不用查菜谱，也不用一次决定完。只要先留一个想吃的方向，晚上就不用从空白开始想。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("候选内容") {
                    TextField("比如：火锅、楼下小馆、回家煮面", text: $title)

                    TextField("补一句很短的备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(existingItem == nil ? "新增候选" : "编辑候选")
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
                            TonightDinnerOption(
                                id: existingItem?.id ?? UUID(),
                                title: normalizedTitle,
                                note: normalizedNote,
                                status: existingItem?.status ?? .candidate,
                                createdAt: existingItem?.createdAt ?? .now,
                                decidedAt: existingItem?.decidedAt,
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

private struct DinnerCardMenu: View {
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
