import Foundation

struct QuickStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let note: String
    let symbol: String
}

struct HomeSnapshot {
    let title: String
    let subtitle: String
    let relationshipDays: Int
    let nextMilestone: String
}

struct HomePartner {
    let name: String
    let initials: String
}

struct HomeCouple {
    let first: HomePartner
    let second: HomePartner
    let sinceText: String
    let relationshipDays: Int
    let note: String
}

enum StatusTone: String, CaseIterable, Codable, Hashable {
    case softGreen
    case berryRose
    case warmApricot
    case mistBlue
    case powderPink

    var label: String {
        switch self {
        case .softGreen:
            return "轻松一点"
        case .berryRose:
            return "有点想念"
        case .warmApricot:
            return "期待着"
        case .mistBlue:
            return "忙一点"
        case .powderPink:
            return "想慢下来"
        }
    }
}

struct DailyStatus: Identifiable {
    let id = UUID()
    let personName: String
    let mood: String
    let tone: StatusTone
}

struct HomeSharedStatus {
    let summary: String
    let updatedText: String
    let tone: StatusTone
}

enum CurrentStatusEffectiveScope: String, CaseIterable, Codable, Identifiable, Hashable {
    case today
    case tonight
    case thisWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:
            return "今天"
        case .tonight:
            return "今晚"
        case .thisWeek:
            return "本周"
        }
    }
}

struct CurrentStatusItem: Identifiable {
    let id: UUID
    let userId: String
    let displayText: String
    let tone: StatusTone
    let effectiveScope: CurrentStatusEffectiveScope
    let spaceId: String
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        displayText: String,
        tone: StatusTone,
        effectiveScope: CurrentStatusEffectiveScope = .today,
        spaceId: String = AppDataDefaults.localSpaceId,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.displayText = displayText
        self.tone = tone
        self.effectiveScope = effectiveScope
        self.spaceId = spaceId
        self.updatedAt = updatedAt
    }
}

struct WhisperNoteItem: Identifiable {
    let id: UUID
    let content: String
    let createdAt: Date
    let createdByUserId: String
    let spaceId: String
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        content: String,
        createdAt: Date = .now,
        createdByUserId: String = AppDataDefaults.localUserId,
        spaceId: String = AppDataDefaults.localSpaceId,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.spaceId = spaceId
        self.syncStatus = syncStatus
    }

    var previewText: String {
        let normalized = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 72 else { return normalized }
        return String(normalized.prefix(72)) + "…"
    }

    var dayText: String {
        Self.dayFormatter.string(from: createdAt)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()
}

struct AnniversaryHighlight {
    let title: String
    let daysRemaining: Int
    let dateText: String
    let note: String
}

enum AnniversaryCategory: String, CaseIterable {
    case together = "在一起"
    case birthday = "生日"
    case travel = "旅行"
    case milestone = "里程碑"
    case custom = "纪念日"

    var symbol: String {
        switch self {
        case .together:
            return "heart.fill"
        case .birthday:
            return "gift.fill"
        case .travel:
            return "tram.fill"
        case .milestone:
            return "sparkles"
        case .custom:
            return "calendar"
        }
    }
}

enum AnniversaryCadence: String, Codable {
    case once
    case yearly
}

struct AnniversaryItem: Identifiable {
    enum ReminderState: Equatable {
        case today
        case upcoming(days: Int)
        case past
    }

    let id: UUID
    let title: String
    let date: Date
    let category: AnniversaryCategory
    let note: String
    let cadence: AnniversaryCadence
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        category: AnniversaryCategory = .custom,
        note: String = "",
        cadence: AnniversaryCadence = .yearly,
        spaceId: String = AppDataDefaults.localSpaceId,
        createdByUserId: String = AppDataDefaults.localUserId,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.category = category
        self.note = note
        self.cadence = cadence
        self.spaceId = spaceId
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.syncStatus = syncStatus
    }

    var dateText: String {
        Self.dateFormatter.string(from: date)
    }

    var shortDateText: String {
        Self.shortDateFormatter.string(from: date)
    }

    var daysSince: Int {
        let calendar = Calendar.current
        let referenceDate = calendar.startOfDay(for: .now)
        let baseDate = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: baseDate, to: referenceDate).day ?? 0
    }

    var nextOccurrenceDate: Date {
        nextReminderDate ?? normalizedDate
    }

    var nextReminderDate: Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let original = normalizedDate

        switch cadence {
        case .once:
            return original >= today ? original : nil
        case .yearly:
            let month = calendar.component(.month, from: original)
            let day = calendar.component(.day, from: original)
            let currentYear = calendar.component(.year, from: today)

            let thisYear = calendar.date(
                from: DateComponents(year: currentYear, month: month, day: day)
            ) ?? original

            if thisYear >= today {
                return thisYear
            }

            return calendar.date(
                from: DateComponents(year: currentYear + 1, month: month, day: day)
            ) ?? thisYear
        }
    }

    var nextReminderDayCount: Int? {
        guard let nextReminderDate else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let nextDate = calendar.startOfDay(for: nextReminderDate)
        return calendar.dateComponents([.day], from: today, to: nextDate).day
    }

    var reminderState: ReminderState {
        guard let days = nextReminderDayCount else {
            return .past
        }

        if days == 0 {
            return .today
        }

        return .upcoming(days: days)
    }

    var hasUpcomingReminder: Bool {
        nextReminderDate != nil
    }

    var daysUntilNextOccurrence: Int {
        nextReminderDayCount ?? {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            return calendar.dateComponents([.day], from: today, to: normalizedDate).day ?? 0
        }()
    }

    var relativeText: String {
        let calendar = Calendar.current
        let referenceDate = calendar.startOfDay(for: .now)
        let targetDate = calendar.startOfDay(for: date)
        let dayCount = calendar.dateComponents([.day], from: referenceDate, to: targetDate).day ?? 0

        switch dayCount {
        case 0:
            return "就是今天"
        case let days where days > 0:
            return "还有 \(days) 天"
        default:
            return "已过去 \(abs(dayCount)) 天"
        }
    }

    var nextReminderText: String {
        switch reminderState {
        case .today:
            return cadence == .yearly ? "就在今天" : "就是今天"
        case let .upcoming(days):
            return cadence == .yearly ? "距下一次还有 \(days) 天" : "还有 \(days) 天"
        case .past:
            return "这一天已经被认真记住"
        }
    }

    var timelineText: String {
        if daysSince >= 0 {
            return "已经走过 \(daysSince) 天"
        }
        return "还有 \(abs(daysSince)) 天会到来"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()

    private var normalizedDate: Date {
        Calendar.current.startOfDay(for: date)
    }

    static func reminderSort(_ lhs: AnniversaryItem, _ rhs: AnniversaryItem) -> Bool {
        switch (lhs.nextReminderDate, rhs.nextReminderDate) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            let leftDate = Calendar.current.startOfDay(for: lhs.date)
            let rightDate = Calendar.current.startOfDay(for: rhs.date)
            if leftDate != rightDate {
                return leftDate > rightDate
            }
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

struct MessageHighlight {
    let fromName: String
    let content: String
    let timeText: String
}

struct LifeEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
}

struct DinnerSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let symbol: String
}

enum TonightDinnerStatus: String, Codable, Hashable {
    case candidate
    case chosen

    var label: String {
        switch self {
        case .candidate:
            return "候选"
        case .chosen:
            return "今晚已定"
        }
    }
}

struct TonightDinnerOption: Identifiable {
    let id: UUID
    let title: String
    let note: String
    let status: TonightDinnerStatus
    let createdAt: Date
    let decidedAt: Date?
    let createdByUserId: String
    let spaceId: String
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        status: TonightDinnerStatus = .candidate,
        createdAt: Date = .now,
        decidedAt: Date? = nil,
        createdByUserId: String = AppDataDefaults.localUserId,
        spaceId: String = AppDataDefaults.localSpaceId,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.decidedAt = decidedAt
        self.createdByUserId = createdByUserId
        self.spaceId = spaceId
        self.syncStatus = syncStatus
    }

    var detailText: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var summaryText: String {
        detailText.isEmpty ? "先把这个选择留在这里，到了饭点就不用重新想一遍。" : detailText
    }

    var createdDayText: String {
        Self.dayFormatter.string(from: createdAt)
    }

    var decidedDayText: String? {
        guard let decidedAt else { return nil }
        return Self.dayFormatter.string(from: decidedAt)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()
}

struct WeeklyPlanItem: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let date: Date
    let hasExplicitTime: Bool

    init(
        title: String,
        note: String,
        date: Date,
        hasExplicitTime: Bool = true
    ) {
        self.title = title
        self.note = note
        self.date = date
        self.hasExplicitTime = hasExplicitTime
    }

    var dayText: String {
        Self.dayFormatter.string(from: date)
    }

    var timeText: String {
        hasExplicitTime ? Self.timeFormatter.string(from: date) : "时间待定"
    }

    var sortDate: Date {
        hasExplicitTime ? date : Calendar(identifier: .gregorian).startOfDay(for: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 EEEE"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

enum WeeklyTodoOwner: String, CaseIterable, Codable, Identifiable {
    case me
    case partner
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .me:
            return "我来"
        case .partner:
            return "对方来"
        case .both:
            return "一起"
        }
    }

    var symbol: String {
        switch self {
        case .me:
            return "person"
        case .partner:
            return "person.fill"
        case .both:
            return "person.2.fill"
        }
    }
}

struct WeeklyTodoItem: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let scheduledDate: Date?
    let owner: WeeklyTodoOwner?
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        scheduledDate: Date? = nil,
        owner: WeeklyTodoOwner? = nil,
        spaceId: String = AppDataDefaults.localSpaceId,
        createdByUserId: String = AppDataDefaults.localUserId,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.scheduledDate = scheduledDate
        self.owner = owner
        self.spaceId = spaceId
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.syncStatus = syncStatus
    }

    var scheduledDateText: String? {
        guard let scheduledDate else { return nil }
        return Self.dateFormatter.string(from: scheduledDate)
    }

    var subtitleText: String {
        var fragments: [String] = []

        if let owner {
            fragments.append(owner.label)
        }

        if let scheduledDateText {
            fragments.append(scheduledDateText)
        }

        return fragments.joined(separator: " · ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()
}

struct PlaceWish: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let note: String
    let category: WishCategory
    let status: WishStatus
    let targetText: String
    let symbol: String
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        note: String = "",
        category: WishCategory = .date,
        status: WishStatus = .dreaming,
        targetText: String = "",
        symbol: String,
        spaceId: String = AppDataDefaults.localSpaceId,
        createdByUserId: String = AppDataDefaults.localUserId,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.note = note
        self.category = category
        self.status = status
        self.targetText = targetText
        self.symbol = symbol
        self.spaceId = spaceId
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.syncStatus = syncStatus
    }
}

enum WishStatus: String, CaseIterable, Identifiable {
    case dreaming = "想做"
    case planning = "计划中"
    case completed = "已完成"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .planning:
            return 0
        case .dreaming:
            return 1
        case .completed:
            return 2
        }
    }

    var symbol: String {
        switch self {
        case .dreaming:
            return "sparkles"
        case .planning:
            return "calendar.badge.clock"
        case .completed:
            return "checkmark.circle.fill"
        }
    }

    var progressValue: Double {
        switch self {
        case .dreaming:
            return 0.25
        case .planning:
            return 0.65
        case .completed:
            return 1
        }
    }
}

enum WishCategory: String, CaseIterable, Identifiable {
    case travel = "旅行"
    case date = "约会"
    case daily = "日常"
    case longTerm = "长期目标"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .travel:
            return "tram.fill"
        case .date:
            return "heart.fill"
        case .daily:
            return "sun.max.fill"
        case .longTerm:
            return "paperplane.fill"
        }
    }
}

enum RitualKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case habit
    case promise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .habit:
            return "小习惯"
        case .promise:
            return "小约定"
        }
    }

    var symbol: String {
        switch self {
        case .habit:
            return "leaf"
        case .promise:
            return "heart"
        }
    }

    var summaryLead: String {
        switch self {
        case .habit:
            return "想慢慢养成的小默契"
        case .promise:
            return "想一起保留下来的约定"
        }
    }
}

struct RitualItem: Identifiable {
    let id: UUID
    let title: String
    let kind: RitualKind
    let isCompleted: Bool
    let note: String
    let createdAt: Date
    let updatedAt: Date
    let createdByUserId: String
    let spaceId: String
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        title: String,
        kind: RitualKind,
        isCompleted: Bool = false,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        createdByUserId: String = AppDataDefaults.localUserId,
        spaceId: String = AppDataDefaults.localSpaceId,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.isCompleted = isCompleted
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.createdByUserId = createdByUserId
        self.spaceId = spaceId
        self.syncStatus = syncStatus
    }

    init(title: String, detail: String, symbol: String) {
        self.init(
            title: title,
            kind: symbol.contains("heart") ? .promise : .habit,
            note: detail
        )
    }

    var detail: String { note }

    var summaryText: String {
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedNote.isEmpty ? "\(kind.summaryLead)，不用写得很正式。" : normalizedNote
    }

    var createdDayText: String {
        Self.dayFormatter.string(from: createdAt)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()
}

struct MemoryEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let dateText: String
}

enum MemoryCategory: String, CaseIterable, Identifiable {
    case date = "约会"
    case daily = "日常"
    case travel = "旅行"
    case milestone = "特别时刻"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .date:
            return "heart.fill"
        case .daily:
            return "sun.max.fill"
        case .travel:
            return "tram.fill"
        case .milestone:
            return "sparkles"
        }
    }
}

struct MemoryTimelineEntry: Identifiable {
    let id: UUID
    let title: String
    let body: String
    let date: Date
    let category: MemoryCategory
    let imageLabel: String
    let photoFilename: String?
    let remoteAssetID: String?
    let mood: String
    let location: String
    let weather: String
    let isFeatured: Bool
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        date: Date,
        category: MemoryCategory,
        imageLabel: String,
        photoFilename: String? = nil,
        remoteAssetID: String? = nil,
        mood: String = "",
        location: String = "",
        weather: String = "",
        isFeatured: Bool = false,
        spaceId: String = AppDataDefaults.localSpaceId,
        createdByUserId: String = AppDataDefaults.localUserId,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.category = category
        self.imageLabel = imageLabel
        self.photoFilename = photoFilename
        self.remoteAssetID = remoteAssetID
        self.mood = mood
        self.location = location
        self.weather = weather
        self.isFeatured = isFeatured
        self.spaceId = spaceId
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.syncStatus = syncStatus
    }

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        date: Date,
        category: MemoryCategory,
        imageLabel: String,
        photoFilename: String? = nil,
        remoteAssetID: String? = nil,
        mood: String = "",
        location: String = "",
        weather: String = "",
        isFeatured: Bool = false,
        spaceId: String = AppDataDefaults.localSpaceId,
        createdByUserId: String = AppDataDefaults.localUserId,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.init(
            id: id,
            title: title,
            body: detail,
            date: date,
            category: category,
            imageLabel: imageLabel,
            photoFilename: photoFilename,
            remoteAssetID: remoteAssetID,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }

    var detail: String { body }

    var dateText: String {
        Self.displayFormatter.string(from: date)
    }

    var monthDayText: String {
        Self.monthDayFormatter.string(from: date)
    }

    var yearMonthText: String {
        Self.yearMonthFormatter.string(from: date)
    }

    var metaItems: [MemoryMetaItem] {
        [
            hasPhoto ? MemoryMetaItem(text: "附一张图片", symbol: "photo") : nil,
            mood.isEmpty ? nil : MemoryMetaItem(text: mood, symbol: "face.smiling"),
            location.isEmpty ? nil : MemoryMetaItem(text: location, symbol: "location"),
            weather.isEmpty ? nil : MemoryMetaItem(text: weather, symbol: "cloud.sun")
        ]
        .compactMap { $0 }
    }

    var hasPhoto: Bool {
        guard let photoFilename else { return false }
        return !photoFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var bodyPreview: String {
        body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var recordContextText: String {
        var fragments = ["写于 \(monthDayText)"]

        if updatedAt.timeIntervalSince(createdAt) > 60 {
            fragments.append("后来补充过")
        }

        return fragments.joined(separator: " · ")
    }

    var bodyExcerpt: String {
        let preview = bodyPreview
        guard preview.count > 88 else { return preview }
        return String(preview.prefix(88)) + "…"
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()

    private static let yearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter
    }()
}

struct MemoryDeletionTombstone: Identifiable, Equatable {
    let id: UUID
    let spaceId: String
    let deletedByUserId: String
    let deletedAt: Date

    init(
        id: UUID,
        spaceId: String,
        deletedByUserId: String,
        deletedAt: Date = .now
    ) {
        self.id = id
        self.spaceId = spaceId
        self.deletedByUserId = deletedByUserId
        self.deletedAt = deletedAt
    }
}

struct MemoryMetaItem: Identifiable {
    let id = UUID()
    let text: String
    let symbol: String
}

enum SyncStatus: String, Codable {
    case localOnly
    case pendingUpload
    case synced

    var label: String {
        switch self {
        case .localOnly:
            return "本地保存"
        case .pendingUpload:
            return "等待同步"
        case .synced:
            return "已同步"
        }
    }
}

enum AccountSyncCopy {
    static let localStorageSummary = "当前内容会先稳稳留在这台设备里。开启账号后，就能继续支持换机恢复和云端共享。"

    static let futureCapabilitySummary = "现在已经可以继续记录和共享。等账号能力接入后，这里会自然延伸到换机恢复、双端同步和云端空间。"

    static func relationshipSummary(for status: CoupleRelationStatus, partnerName: String) -> String {
        switch status {
        case .unpaired:
            return "现在还没有接入账号，但已经可以先在本机开始记录。以后登录账号时，这些内容会从这里继续接上。"
        case .inviting:
            return "邀请状态和当前内容都已经留在本机。等账号能力开启后，这条关系会继续延伸到换机恢复和云端共享。"
        case .paired:
            return "当前已经与 \(partnerName) 进入同一个共享空间。以后接入账号后，这个双人空间会自然继续到双端同步。"
        }
    }
}

enum AppDataDefaults {
    static let localSpaceId = "space-local-demo"
    static let localUserId = "user-local-demo"
}

struct ProfileAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
}

struct PartnerProfile {
    let nickname: String
    let signature: String
    let city: String
}

struct RelationshipSpaceProfile {
    let title: String
    let subtitle: String
    let city: String
    let spaceTag: String
    let relationshipDays: Int
    let createdText: String
}

struct SpaceInsight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let note: String
}

enum SettingsDestination {
    case spaceSettings
    case anniversaryManagement
    case accountSync
    case none
}

struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let destination: SettingsDestination
}
