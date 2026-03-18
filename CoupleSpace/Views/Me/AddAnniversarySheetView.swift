import SwiftUI

struct AddAnniversarySheetView: View {
    @Environment(\.dismiss) private var dismiss

    let existingItem: AnniversaryItem?
    let onSave: (AnniversaryItem) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var category: AnniversaryCategory
    @State private var cadence: AnniversaryCadence
    @State private var note: String

    init(
        existingItem: AnniversaryItem? = nil,
        onSave: @escaping (AnniversaryItem) -> Void
    ) {
        self.existingItem = existingItem
        self.onSave = onSave
        _title = State(initialValue: existingItem?.title ?? "")
        _date = State(initialValue: existingItem?.date ?? Calendar.current.startOfDay(for: .now))
        _category = State(initialValue: existingItem?.category ?? .custom)
        _cadence = State(initialValue: existingItem?.cadence ?? .yearly)
        _note = State(initialValue: existingItem?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("先记住一个舍不得忘的时间点")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不用一下子整理很多，从相识、在一起，或某一次很想认真留住的出发开始就很好。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("纪念日信息") {
                    TextField("名称", text: $title)

                    DatePicker("日期", selection: $date, displayedComponents: .date)

                    Picker("类型", selection: $category) {
                        ForEach(AnniversaryCategory.allCases, id: \.rawValue) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("提醒方式", selection: $cadence) {
                        ForEach([AnniversaryCadence.once, .yearly], id: \.rawValue) { item in
                            Text(item == .yearly ? "每年提醒" : "只记这一次").tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("补一句备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .navigationTitle(existingItem == nil ? "新增纪念日" : "编辑纪念日")
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
                            AnniversaryItem(
                                id: existingItem?.id ?? UUID(),
                                title: normalizedTitle,
                                date: Calendar.current.startOfDay(for: date),
                                category: category,
                                note: normalizedNote,
                                cadence: cadence,
                                spaceId: existingItem?.spaceId ?? AppDataDefaults.localSpaceId,
                                createdByUserId: existingItem?.createdByUserId ?? AppDataDefaults.localUserId,
                                createdAt: existingItem?.createdAt ?? .now,
                                updatedAt: existingItem?.updatedAt ?? .now,
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
