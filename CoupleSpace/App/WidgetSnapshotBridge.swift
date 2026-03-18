import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSnapshotBridge {
    static func refreshAllSnapshots(
        relationship: CoupleRelationshipState,
        anniversaries: [AnniversaryItem],
        entries: [MemoryTimelineEntry],
        now: Date = .now
    ) {
        refreshAnniversarySnapshot(
            relationship: relationship,
            anniversaries: anniversaries,
            now: now
        )
        refreshMemorySnapshot(
            relationship: relationship,
            entries: entries,
            now: now
        )
    }

    static func refreshAnniversarySnapshot(
        relationship: CoupleRelationshipState,
        anniversaries: [AnniversaryItem],
        now: Date = .now
    ) {
        let scope = relationship.contentScope
        let scopedItems = anniversaries
            .filter {
                $0.spaceId == scope.spaceId
                || (scope.isSharedSpace && $0.spaceId == AppDataDefaults.localSpaceId)
            }
            .sorted(by: AnniversaryItem.reminderSort(_:_:))

        let nextAnniversary = scopedItems.first(where: \.hasUpcomingReminder).map {
            WidgetAnniversaryItemSnapshot(
                id: $0.id,
                title: $0.title,
                date: $0.date,
                cadence: $0.cadence == .yearly ? .yearly : .once,
                note: $0.note,
                shortDateText: $0.shortDateText
            )
        }

        WidgetAnniversarySnapshotStore.save(
            WidgetAnniversarySnapshot(
                generatedAt: now,
                spaceTitle: relationship.spaceDisplayTitle,
                relationshipLabel: relationship.relationStatus.label,
                anniversaryCount: scopedItems.count,
                nextAnniversary: nextAnniversary
            )
        )

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AppWidgetKind.anniversary)
        #endif
    }

    static func refreshMemorySnapshot(
        relationship: CoupleRelationshipState,
        entries: [MemoryTimelineEntry],
        now: Date = .now
    ) {
        let scope = relationship.contentScope
        let scopedEntries = entries
            .filter {
                $0.spaceId == scope.spaceId
                || (scope.isSharedSpace && $0.spaceId == AppDataDefaults.localSpaceId)
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        let latestEntry = scopedEntries.first.map {
            WidgetMemoryItemSnapshot(
                id: $0.id,
                title: $0.title,
                excerpt: widgetMemoryExcerpt(from: $0.bodyPreview),
                date: $0.date,
                shortDateText: $0.monthDayText,
                contextText: widgetMemoryContextText(for: $0)
            )
        }

        WidgetMemorySnapshotStore.save(
            WidgetMemorySnapshot(
                generatedAt: now,
                spaceTitle: relationship.spaceDisplayTitle,
                entryCount: scopedEntries.count,
                latestEntry: latestEntry
            )
        )

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AppWidgetKind.memory)
        #endif
    }

    private static func widgetMemoryExcerpt(from preview: String) -> String {
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 72 else { return trimmed }
        return String(trimmed.prefix(72)) + "…"
    }

    private static func widgetMemoryContextText(for entry: MemoryTimelineEntry) -> String {
        if entry.updatedAt.timeIntervalSince(entry.createdAt) > 60 {
            return "后来补充过"
        }

        return "最近写下"
    }
}
