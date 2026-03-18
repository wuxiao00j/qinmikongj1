import SwiftUI

struct AddWeeklyPlanSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (WeeklyPlanItem) -> Void

    @State private var title = ""
    @State private var date = Calendar.current.startOfDay(for: .now)
    @State private var includesTime = true
    @State private var time = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("先把一段要一起留出来的时间记下")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不用把细节一次想完，只要先把想一起做的事和大概时间留住，临近时再慢慢补充。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("安排内容") {
                    TextField("要一起做什么", text: $title)

                    DatePicker("日期", selection: $date, displayedComponents: .date)

                    Toggle("补充具体时间", isOn: $includesTime)

                    if includesTime {
                        DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                    }

                    TextField("补一句小备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .navigationTitle("新增安排")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(
                            WeeklyPlanItem(
                                title: normalizedTitle,
                                note: normalizedNote,
                                date: composedDate,
                                hasExplicitTime: includesTime
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
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "先把这段一起留出来，到了那天再决定细节。" : trimmed
    }

    private var composedDate: Date {
        guard includesTime else {
            return Calendar.current.startOfDay(for: date)
        }

        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.date(
            from: DateComponents(
                year: dayComponents.year,
                month: dayComponents.month,
                day: dayComponents.day,
                hour: timeComponents.hour,
                minute: timeComponents.minute
            )
        ) ?? date
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty
    }
}
