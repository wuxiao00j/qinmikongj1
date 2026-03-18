import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LocalBackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let relationship: CoupleRelationshipState
    let memories: [LocalBackupMemoryEntry]
    let wishes: [LocalBackupWish]
    let anniversaries: [LocalBackupAnniversary]
    let weeklyTodos: [LocalBackupWeeklyTodo]
    let tonightDinners: [LocalBackupTonightDinner]
    let rituals: [LocalBackupRitual]
    let currentStatuses: [LocalBackupCurrentStatus]
    let whisperNotes: [LocalBackupWhisperNote]?

    var restoredWhisperNotes: [LocalBackupWhisperNote] {
        whisperNotes ?? []
    }

    var totalItemCount: Int {
        memories.count
        + wishes.count
        + anniversaries.count
        + weeklyTodos.count
        + tonightDinners.count
        + rituals.count
        + currentStatuses.count
        + restoredWhisperNotes.count
    }
}

struct LocalBackupMemoryEntry: Codable {
    let id: UUID
    let title: String
    let body: String
    let date: Date
    let categoryRawValue: String
    let imageLabel: String
    let mood: String
    let location: String
    let weather: String
    let isFeatured: Bool
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(entry: MemoryTimelineEntry) {
        id = entry.id
        title = entry.title
        body = entry.body
        date = entry.date
        categoryRawValue = entry.category.rawValue
        imageLabel = entry.imageLabel
        mood = entry.mood
        location = entry.location
        weather = entry.weather
        isFeatured = entry.isFeatured
        spaceId = entry.spaceId
        createdByUserId = entry.createdByUserId
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        syncStatusRawValue = entry.syncStatus.rawValue
    }

    var model: MemoryTimelineEntry {
        MemoryTimelineEntry(
            id: id,
            title: title,
            body: body,
            date: date,
            category: MemoryCategory(rawValue: categoryRawValue) ?? .daily,
            imageLabel: imageLabel,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupWish: Codable {
    let id: UUID
    let title: String
    let detail: String
    let note: String
    let categoryRawValue: String
    let statusRawValue: String
    let targetText: String
    let symbol: String
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(wish: PlaceWish) {
        id = wish.id
        title = wish.title
        detail = wish.detail
        note = wish.note
        categoryRawValue = wish.category.rawValue
        statusRawValue = wish.status.rawValue
        targetText = wish.targetText
        symbol = wish.symbol
        spaceId = wish.spaceId
        createdByUserId = wish.createdByUserId
        createdAt = wish.createdAt
        updatedAt = wish.updatedAt
        syncStatusRawValue = wish.syncStatus.rawValue
    }

    var model: PlaceWish {
        PlaceWish(
            id: id,
            title: title,
            detail: detail,
            note: note,
            category: WishCategory(rawValue: categoryRawValue) ?? .date,
            status: WishStatus(rawValue: statusRawValue) ?? .dreaming,
            targetText: targetText,
            symbol: symbol,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupAnniversary: Codable {
    let id: UUID
    let title: String
    let date: Date
    let categoryRawValue: String
    let note: String
    let cadenceRawValue: String
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(item: AnniversaryItem) {
        id = item.id
        title = item.title
        date = item.date
        categoryRawValue = item.category.rawValue
        note = item.note
        cadenceRawValue = item.cadence.rawValue
        spaceId = item.spaceId
        createdByUserId = item.createdByUserId
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: AnniversaryItem {
        AnniversaryItem(
            id: id,
            title: title,
            date: date,
            category: AnniversaryCategory(rawValue: categoryRawValue) ?? .custom,
            note: note,
            cadence: AnniversaryCadence(rawValue: cadenceRawValue) ?? .yearly,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupWeeklyTodo: Codable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let scheduledDate: Date?
    let ownerRawValue: String?
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(item: WeeklyTodoItem) {
        id = item.id
        title = item.title
        isCompleted = item.isCompleted
        scheduledDate = item.scheduledDate
        ownerRawValue = item.owner?.rawValue
        spaceId = item.spaceId
        createdByUserId = item.createdByUserId
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: WeeklyTodoItem {
        WeeklyTodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: ownerRawValue.flatMap(WeeklyTodoOwner.init(rawValue:)),
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupTonightDinner: Codable {
    let id: UUID
    let title: String
    let note: String
    let statusRawValue: String
    let createdAt: Date
    let decidedAt: Date?
    let createdByUserId: String
    let spaceId: String
    let syncStatusRawValue: String

    init(item: TonightDinnerOption) {
        id = item.id
        title = item.title
        note = item.note
        statusRawValue = item.status.rawValue
        createdAt = item.createdAt
        decidedAt = item.decidedAt
        createdByUserId = item.createdByUserId
        spaceId = item.spaceId
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: TonightDinnerOption {
        TonightDinnerOption(
            id: id,
            title: title,
            note: note,
            status: TonightDinnerStatus(rawValue: statusRawValue) ?? .candidate,
            createdAt: createdAt,
            decidedAt: decidedAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupRitual: Codable {
    let id: UUID
    let title: String
    let kindRawValue: String
    let isCompleted: Bool
    let note: String
    let createdAt: Date
    let updatedAt: Date
    let createdByUserId: String
    let spaceId: String
    let syncStatusRawValue: String

    init(item: RitualItem) {
        id = item.id
        title = item.title
        kindRawValue = item.kind.rawValue
        isCompleted = item.isCompleted
        note = item.note
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        createdByUserId = item.createdByUserId
        spaceId = item.spaceId
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: RitualItem {
        RitualItem(
            id: id,
            title: title,
            kind: RitualKind(rawValue: kindRawValue) ?? .promise,
            isCompleted: isCompleted,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupCurrentStatus: Codable {
    let id: UUID
    let userId: String
    let displayText: String
    let toneRawValue: String
    let effectiveScopeRawValue: String
    let spaceId: String
    let updatedAt: Date

    init(item: CurrentStatusItem) {
        id = item.id
        userId = item.userId
        displayText = item.displayText
        toneRawValue = item.tone.rawValue
        effectiveScopeRawValue = item.effectiveScope.rawValue
        spaceId = item.spaceId
        updatedAt = item.updatedAt
    }

    var model: CurrentStatusItem {
        CurrentStatusItem(
            id: id,
            userId: userId,
            displayText: displayText,
            tone: StatusTone(rawValue: toneRawValue) ?? .softGreen,
            effectiveScope: CurrentStatusEffectiveScope(rawValue: effectiveScopeRawValue) ?? .today,
            spaceId: spaceId,
            updatedAt: updatedAt
        )
    }
}

struct LocalBackupWhisperNote: Codable {
    let id: UUID
    let content: String
    let createdAt: Date
    let createdByUserId: String
    let spaceId: String
    let syncStatusRawValue: String

    init(item: WhisperNoteItem) {
        id = item.id
        content = item.content
        createdAt = item.createdAt
        createdByUserId = item.createdByUserId
        spaceId = item.spaceId
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: WhisperNoteItem {
        WhisperNoteItem(
            id: id,
            content: content,
            createdAt: createdAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

struct LocalBackupRestoreSummary {
    let relationshipTitle: String
    let memoryCount: Int
    let wishCount: Int
    let anniversaryCount: Int
    let weeklyTodoCount: Int
    let tonightDinnerCount: Int
    let ritualCount: Int
    let currentStatusCount: Int
    let whisperNoteCount: Int
    let restoredScope: AppContentScope

    var message: String {
        "已恢复 \(relationshipTitle) 的本地数据：\(memoryCount) 段记录、\(wishCount) 个愿望、\(anniversaryCount) 个纪念日、\(weeklyTodoCount) 条本周事项、\(tonightDinnerCount) 个晚饭候选、\(ritualCount) 条小默契、\(currentStatusCount) 条当前状态、\(whisperNoteCount) 张悄悄话。"
    }
}

enum LocalBackupService {
    static let currentSchemaVersion = 1

    static func makePayload(
        relationship: CoupleRelationshipState,
        memories: [MemoryTimelineEntry],
        wishes: [PlaceWish],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        exportedAt: Date = .now
    ) -> LocalBackupPayload {
        LocalBackupPayload(
            schemaVersion: currentSchemaVersion,
            exportedAt: exportedAt,
            relationship: relationship,
            memories: memories.map(LocalBackupMemoryEntry.init(entry:)),
            wishes: wishes.map(LocalBackupWish.init(wish:)),
            anniversaries: anniversaries.map(LocalBackupAnniversary.init(item:)),
            weeklyTodos: weeklyTodos.map(LocalBackupWeeklyTodo.init(item:)),
            tonightDinners: tonightDinners.map(LocalBackupTonightDinner.init(item:)),
            rituals: rituals.map(LocalBackupRitual.init(item:)),
            currentStatuses: currentStatuses.map(LocalBackupCurrentStatus.init(item:)),
            whisperNotes: whisperNotes.map(LocalBackupWhisperNote.init(item:))
        )
    }

    static func validate(_ payload: LocalBackupPayload) throws {
        guard payload.schemaVersion == currentSchemaVersion else {
            throw LocalBackupError.unsupportedSchemaVersion(payload.schemaVersion)
        }
    }

    @MainActor
    static func restore(
        _ payload: LocalBackupPayload,
        currentScope: AppContentScope,
        relationshipStore: RelationshipStore,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore
    ) throws -> LocalBackupRestoreSummary {
        try validate(payload)

        let restoredScope = payload.relationship.contentScope
        if currentScope.spaceId != restoredScope.spaceId || currentScope.isSharedSpace != restoredScope.isSharedSpace {
            memoryStore.replaceEntries(in: currentScope, with: [])
            wishStore.replaceWishes(in: currentScope, with: [])
            anniversaryStore.replaceAnniversaries(in: currentScope, with: [])
            weeklyTodoStore.replaceItems(in: currentScope, with: [])
            tonightDinnerStore.replaceItems(in: currentScope, with: [])
            ritualStore.replaceItems(in: currentScope, with: [])
            currentStatusStore.replaceStatuses(in: currentScope, with: [])
            whisperNoteStore.replaceItems(in: currentScope, with: [])
        }

        relationshipStore.restoreFromBackup(payload.relationship)
        memoryStore.replaceEntries(in: restoredScope, with: payload.memories.map(\.model))
        wishStore.replaceWishes(in: restoredScope, with: payload.wishes.map(\.model))
        anniversaryStore.replaceAnniversaries(in: restoredScope, with: payload.anniversaries.map(\.model))
        weeklyTodoStore.replaceItems(in: restoredScope, with: payload.weeklyTodos.map(\.model))
        tonightDinnerStore.replaceItems(in: restoredScope, with: payload.tonightDinners.map(\.model))
        ritualStore.replaceItems(in: restoredScope, with: payload.rituals.map(\.model))
        currentStatusStore.replaceStatuses(in: restoredScope, with: payload.currentStatuses.map(\.model))
        whisperNoteStore.replaceItems(in: restoredScope, with: payload.restoredWhisperNotes.map(\.model))

        return LocalBackupRestoreSummary(
            relationshipTitle: payload.relationship.spaceDisplayTitle,
            memoryCount: payload.memories.count,
            wishCount: payload.wishes.count,
            anniversaryCount: payload.anniversaries.count,
            weeklyTodoCount: payload.weeklyTodos.count,
            tonightDinnerCount: payload.tonightDinners.count,
            ritualCount: payload.rituals.count,
            currentStatusCount: payload.currentStatuses.count,
            whisperNoteCount: payload.restoredWhisperNotes.count,
            restoredScope: restoredScope
        )
    }

    static func defaultFilename(
        relationship: CoupleRelationshipState,
        exportedAt: Date
    ) -> String {
        let name = normalizedFilenameComponent(relationship.space?.title ?? relationship.currentUser.nickname)
        return "couplespace-backup-\(name)-\(filenameDateFormatter.string(from: exportedAt))"
    }

    private static func normalizedFilenameComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.isEmpty ? "local-space" : trimmed.replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = collapsed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let normalized = String(scalars).replacingOccurrences(of: "--", with: "-")
        let sanitized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? "local-space" : sanitized
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

enum LocalBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "这个备份文件的版本是 \(version)，当前 App 暂时还不能导入。"
        case .unreadableFile:
            return "这份备份文件暂时无法读取，请重新导出或换一份文件再试。"
        }
    }
}

struct LocalBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let payload: LocalBackupPayload

    init(payload: LocalBackupPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw LocalBackupError.unreadableFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LocalBackupPayload.self, from: data)
        try LocalBackupService.validate(payload)
        self.payload = payload
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return FileWrapper(regularFileWithContents: data)
    }

    static func read(from url: URL) throws -> LocalBackupPayload {
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LocalBackupPayload.self, from: data)
        try LocalBackupService.validate(payload)
        return payload
    }
}
