import SwiftUI
import WidgetKit

struct AnniversaryTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetAnniversarySnapshot
}

struct AnniversaryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AnniversaryTimelineEntry {
        AnniversaryTimelineEntry(
            date: .now,
            snapshot: WidgetAnniversarySnapshot(
                generatedAt: .now,
                spaceTitle: "情侣空间",
                relationshipLabel: "已绑定",
                anniversaryCount: 1,
                nextAnniversary: WidgetAnniversaryItemSnapshot(
                    id: UUID(),
                    title: "在一起纪念日",
                    date: .now.addingTimeInterval(86_400 * 3),
                    cadence: .yearly,
                    note: "",
                    shortDateText: "3 月 20 日"
                )
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AnniversaryTimelineEntry) -> Void) {
        completion(
            AnniversaryTimelineEntry(
                date: .now,
                snapshot: WidgetAnniversarySnapshotStore.load() ?? emptySnapshot()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AnniversaryTimelineEntry>) -> Void) {
        let entry = AnniversaryTimelineEntry(
            date: .now,
            snapshot: WidgetAnniversarySnapshotStore.load() ?? emptySnapshot()
        )

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextRefreshDate(after: entry.date))
            )
        )
    }

    private func nextRefreshDate(after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86_400)
    }

    private func emptySnapshot() -> WidgetAnniversarySnapshot {
        WidgetAnniversarySnapshot(
            generatedAt: .now,
            spaceTitle: "情侣空间",
            relationshipLabel: "本地空间",
            anniversaryCount: 0,
            nextAnniversary: nil
        )
    }
}

struct AnniversaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppWidgetKind.anniversary, provider: AnniversaryWidgetProvider()) { entry in
            AnniversaryWidgetEntryView(entry: entry)
                .widgetURL(AppWidgetRoute.anniversaryURL)
        }
        .configurationDisplayName("纪念日")
        .description("把最近的一个重要日子轻轻留在桌面上。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct AnniversaryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: AnniversaryTimelineEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumBody
            default:
                smallBody
            }
        }
        .containerBackground(backgroundGradient, for: .widget)
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetLabel(text: "纪念日", detail: nil, systemImage: "calendar.badge.clock")

            Spacer(minLength: 0)

            if let item = entry.snapshot.nextAnniversary {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WidgetPalette.title)
                        .lineLimit(2)

                    Text(primaryCountdownText(for: item))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.accent)
                        .lineLimit(1)

                    Text(detailLine(for: item))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetPalette.subtitle)
                        .lineLimit(1)
                }
            } else if entry.snapshot.anniversaryCount > 0 {
                emptyState(
                    title: "最近没有待提醒的日子",
                    message: "重要时刻还留在纪念日页里。"
                )
            } else {
                emptyState(
                    title: "还没有纪念日",
                    message: "打开后写下第一个重要日子。"
                )
            }
        }
        .padding(16)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                widgetLabel(
                    text: "纪念日",
                    detail: entry.snapshot.spaceTitle,
                    systemImage: "calendar.badge.clock"
                )

                if let item = entry.snapshot.nextAnniversary {
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WidgetPalette.title)
                        .lineLimit(2)

                    Text(primaryCountdownText(for: item))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.accent)
                        .lineLimit(1)

                    Text(detailLine(for: item))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WidgetPalette.subtitle)
                        .lineLimit(1)
                } else if entry.snapshot.anniversaryCount > 0 {
                    emptyState(
                        title: "最近没有待提醒的日子",
                        message: "已留住的重要时刻，会继续安静待在纪念日页里。"
                    )
                } else {
                    emptyState(
                        title: "还没有纪念日",
                        message: "写下第一个重要日子，桌面就会开始提醒你们的时间线。"
                    )
                }
            }

            Spacer(minLength: 0)

            sidePanel
        }
        .padding(18)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.94, green: 0.96, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.snapshot.relationshipLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetPalette.accent)

            if let item = entry.snapshot.nextAnniversary {
                Text(secondaryText(for: item))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WidgetPalette.title)
                    .lineLimit(3)

                Text(panelNoteText(for: item))
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.subtitle)
                    .lineSpacing(2)
                    .lineLimit(3)
            } else if entry.snapshot.anniversaryCount > 0 {
                Text("最近没有待提醒的日子。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WidgetPalette.title)
                    .lineLimit(3)

                Text(entry.snapshot.anniversaryCount == 1 ? "已留住 1 个重要日子" : "已留住 \(entry.snapshot.anniversaryCount) 个重要日子")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.subtitle)
            } else {
                Text("打开后写下第一个重要日子。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WidgetPalette.title)
                    .lineLimit(3)

                Text("进入纪念日页")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.subtitle)
            }
        }
        .padding(12)
        .frame(width: 112, alignment: .leading)
        .background(WidgetPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func widgetLabel(text: String, detail: String?, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
            Label(text, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetPalette.accent)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetPalette.muted)
                    .lineLimit(1)
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(WidgetPalette.title)

            Text(message)
                .font(.caption)
                .foregroundStyle(WidgetPalette.subtitle)
                .lineSpacing(3)
                .lineLimit(3)
        }
    }

    private func primaryCountdownText(for item: WidgetAnniversaryItemSnapshot) -> String {
        let days = dayDistance(for: item)
        switch item.cadence {
        case .yearly:
            if days == 0 {
                return "今天"
            }
            return "\(days) 天后"
        case .once:
            if days == 0 {
                return "今天"
            }
            if days > 0 {
                return "\(days) 天后"
            }
            return "\(abs(days)) 天前"
        }
    }

    private func secondaryText(for item: WidgetAnniversaryItemSnapshot) -> String {
        let days = dayDistance(for: item)
        switch item.cadence {
        case .yearly:
            return days == 0 ? "今年的这一天到了" : "下一次是 \(item.shortDateText)"
        case .once:
            if days == 0 {
                return "就是 \(item.shortDateText)"
            }
            if days > 0 {
                return "就在 \(item.shortDateText)"
            }
            return "那一天是 \(item.shortDateText)"
        }
    }

    private func detailLine(for item: WidgetAnniversaryItemSnapshot) -> String {
        if item.cadence == .yearly {
            return "\(item.shortDateText) · 每年提醒"
        }
        return item.shortDateText
    }

    private func panelNoteText(for item: WidgetAnniversaryItemSnapshot) -> String {
        let trimmedNote = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            return entry.snapshot.anniversaryCount == 1
                ? "已经留住 1 个重要日子"
                : "已经留住 \(entry.snapshot.anniversaryCount) 个重要日子"
        }

        return trimmedNote
    }

    private func dayDistance(for item: WidgetAnniversaryItemSnapshot) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: entry.date)
        let baseDate = calendar.startOfDay(for: item.date)

        switch item.cadence {
        case .once:
            return calendar.dateComponents([.day], from: today, to: baseDate).day ?? 0
        case .yearly:
            let month = calendar.component(.month, from: baseDate)
            let day = calendar.component(.day, from: baseDate)
            let currentYear = calendar.component(.year, from: today)

            let thisYear = calendar.date(
                from: DateComponents(year: currentYear, month: month, day: day)
            ) ?? baseDate

            let nextDate = thisYear >= today
                ? thisYear
                : calendar.date(from: DateComponents(year: currentYear + 1, month: month, day: day)) ?? thisYear

            return calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
        }
    }
}

private enum WidgetPalette {
    static let title = Color(red: 0.17, green: 0.21, blue: 0.25)
    static let subtitle = Color(red: 0.39, green: 0.45, blue: 0.49)
    static let muted = Color(red: 0.48, green: 0.54, blue: 0.58)
    static let accent = Color(red: 0.34, green: 0.45, blue: 0.56)
    static let panel = Color.white.opacity(0.78)
}
