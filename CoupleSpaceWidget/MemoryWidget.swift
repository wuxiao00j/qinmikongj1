import SwiftUI
import WidgetKit

struct MemoryTimelineWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMemorySnapshot
}

struct MemoryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoryTimelineWidgetEntry {
        MemoryTimelineWidgetEntry(
            date: .now,
            snapshot: WidgetMemorySnapshot(
                generatedAt: .now,
                spaceTitle: "情侣空间",
                entryCount: 1,
                latestEntry: WidgetMemoryItemSnapshot(
                    id: UUID(),
                    title: "一起去超市的晚上",
                    excerpt: "买完菜回来路上风有点凉，最后还是决定回家煮面，那个很普通的晚上现在想起来还是很安静。",
                    date: .now,
                    shortDateText: "3 月 17 日",
                    contextText: "写于 3 月 17 日"
                )
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryTimelineWidgetEntry) -> Void) {
        completion(
            MemoryTimelineWidgetEntry(
                date: .now,
                snapshot: WidgetMemorySnapshotStore.load() ?? emptySnapshot()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryTimelineWidgetEntry>) -> Void) {
        let entry = MemoryTimelineWidgetEntry(
            date: .now,
            snapshot: WidgetMemorySnapshotStore.load() ?? emptySnapshot()
        )

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextRefreshDate(after: entry.date))
            )
        )
    }

    private func nextRefreshDate(after date: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: 6, to: date) ?? date.addingTimeInterval(21_600)
    }

    private func emptySnapshot() -> WidgetMemorySnapshot {
        WidgetMemorySnapshot(
            generatedAt: .now,
            spaceTitle: "情侣空间",
            entryCount: 0,
            latestEntry: nil
        )
    }
}

struct MemoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppWidgetKind.memory, provider: MemoryWidgetProvider()) { entry in
            MemoryWidgetEntryView(entry: entry)
                .widgetURL(AppWidgetRoute.memoryURL)
        }
        .configurationDisplayName("生活记录")
        .description("把最近写下的一段日常，轻轻留在桌面上。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct MemoryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MemoryTimelineWidgetEntry

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
            widgetLabel(text: "生活记录", detail: nil, systemImage: "book.closed.fill")

            Spacer(minLength: 0)

            if let item = entry.snapshot.latestEntry {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemoryWidgetPalette.title)
                        .lineLimit(2)

                    Text(condensedExcerpt(item.excerpt, limit: 38))
                        .font(.caption)
                        .foregroundStyle(MemoryWidgetPalette.subtitle)
                        .lineSpacing(3)
                        .lineLimit(2)

                    Text("\(item.shortDateText) · \(entry.snapshot.entryCount) 条记录")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MemoryWidgetPalette.muted)
                        .lineLimit(1)
                }
            } else {
                emptyState(
                    title: "还没有生活记录",
                    message: "打开后写下第一段日常。"
                )
            }
        }
        .padding(16)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                widgetLabel(
                    text: "生活记录",
                    detail: entry.snapshot.spaceTitle,
                    systemImage: "book.closed.fill"
                )

                if let item = entry.snapshot.latestEntry {
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MemoryWidgetPalette.title)
                        .lineLimit(2)

                    Text(condensedExcerpt(item.excerpt, limit: 76))
                        .font(.footnote)
                        .foregroundStyle(MemoryWidgetPalette.subtitle)
                        .lineSpacing(3)
                        .lineLimit(3)
                } else {
                    emptyState(
                        title: "还没有生活记录",
                        message: "写下一段最近的日常，桌面就会留下你们的一页记录。"
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
                Color(red: 0.94, green: 0.96, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let item = entry.snapshot.latestEntry {
                Text(item.shortDateText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoryWidgetPalette.accent)

                Text(item.contextText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MemoryWidgetPalette.title)
                    .lineLimit(3)

                Text(entry.snapshot.entryCount == 1 ? "已经留住 1 段记录" : "已经留住 \(entry.snapshot.entryCount) 段记录")
                    .font(.caption)
                    .foregroundStyle(MemoryWidgetPalette.subtitle)
                    .lineLimit(2)
            } else {
                Text("还没有生活记录")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MemoryWidgetPalette.title)

                Text("打开后进入记忆页")
                    .font(.caption)
                    .foregroundStyle(MemoryWidgetPalette.subtitle)
            }
        }
        .padding(12)
        .frame(width: 112, alignment: .leading)
        .background(MemoryWidgetPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func widgetLabel(text: String, detail: String?, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
            Label(text, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoryWidgetPalette.accent)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(MemoryWidgetPalette.muted)
                    .lineLimit(1)
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(MemoryWidgetPalette.title)

            Text(message)
                .font(.caption)
                .foregroundStyle(MemoryWidgetPalette.subtitle)
                .lineSpacing(3)
                .lineLimit(3)
        }
    }

    private func condensedExcerpt(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }
}

private enum MemoryWidgetPalette {
    static let title = Color(red: 0.17, green: 0.21, blue: 0.25)
    static let subtitle = Color(red: 0.39, green: 0.45, blue: 0.49)
    static let muted = Color(red: 0.48, green: 0.54, blue: 0.58)
    static let accent = Color(red: 0.38, green: 0.49, blue: 0.44)
    static let panel = Color.white.opacity(0.78)
}
