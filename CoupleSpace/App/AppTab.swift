import Combine
import Foundation
import UIKit

enum AppTab: Hashable {
    case home
    case life
    case memory
    case me
}

enum AppDeepLink: Equatable {
    case anniversaryManagement
}

final class AppNavigationState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var pendingDeepLink: AppDeepLink?

    func handleOpenURL(_ url: URL) {
        if AppWidgetRoute.matchesAnniversary(url) {
            selectedTab = .me
            pendingDeepLink = .anniversaryManagement
            return
        }

        if AppWidgetRoute.matchesMemory(url) {
            selectedTab = .memory
        }
    }

    func consumePendingDeepLink(_ deepLink: AppDeepLink) {
        guard pendingDeepLink == deepLink else { return }
        pendingDeepLink = nil
    }
}

@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var entries: [MemoryTimelineEntry] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.memoryEntries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var hasPersistedEntries: Bool {
        !entries.isEmpty
    }

    func entries(in scope: AppContentScope) -> [MemoryTimelineEntry] {
        entries
            .filter { $0.matches(scope: scope) }
            .sorted { $0.date > $1.date }
    }

    func add(_ entry: MemoryTimelineEntry, in scope: AppContentScope) {
        entries.append(entry.preparedForLocalInsert(in: scope))
        entries.sort { $0.date > $1.date }
        save()
    }

    func update(_ entry: MemoryTimelineEntry, in scope: AppContentScope) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id && $0.matches(scope: scope) }) else {
            return
        }

        let existingPhotoFilename = entries[index].photoFilename
        let updatedEntry = entries[index].preparedForContentUpdate(
            title: entry.title,
            body: entry.body,
            date: entry.date,
            category: entry.category,
            imageLabel: entry.imageLabel,
            photoFilename: entry.photoFilename,
            mood: entry.mood,
            location: entry.location,
            weather: entry.weather,
            scope: scope
        )

        entries[index] = updatedEntry
        entries.sort { $0.date > $1.date }

        if existingPhotoFilename != updatedEntry.photoFilename {
            MemoryPhotoStorage.deleteImage(for: existingPhotoFilename)
        }

        save()
    }

    func delete(_ entryID: UUID, in scope: AppContentScope) {
        guard let existingEntry = entries.first(where: { $0.id == entryID && $0.matches(scope: scope) }) else {
            return
        }

        entries.removeAll { $0.id == entryID && $0.matches(scope: scope) }
        MemoryPhotoStorage.deleteImage(for: existingEntry.photoFilename)
        save()
    }

    func replaceEntries(in scope: AppContentScope, with importedEntries: [MemoryTimelineEntry]) {
        entries.removeAll { $0.matches(scope: scope) }
        entries.append(contentsOf: importedEntries.map { $0.preparedForScopeReplacement(in: scope) })
        entries.sort { $0.date > $1.date }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            entries = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let storedEntries = try decoder.decode([StoredMemoryEntry].self, from: data)
            entries = storedEntries
                .map(\.model)
                .sorted { $0.date > $1.date }
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries.map { StoredMemoryEntry(entry: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save memory entries: \(error)")
        }
    }
}

@MainActor
final class WishStore: ObservableObject {
    @Published private(set) var wishes: [PlaceWish] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.placeWishes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var hasPersistedWishes: Bool {
        !wishes.isEmpty
    }

    func wishes(in scope: AppContentScope) -> [PlaceWish] {
        wishes
            .filter { $0.matches(scope: scope) }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.title < rhs.title
                }

                return lhs.status.sortOrder < rhs.status.sortOrder
            }
    }

    func add(_ wish: PlaceWish, in scope: AppContentScope) {
        wishes.append(wish.preparedForLocalInsert(in: scope))
        save()
    }

    func update(_ wish: PlaceWish, in scope: AppContentScope) {
        guard let index = wishes.firstIndex(where: { $0.id == wish.id && $0.matches(scope: scope) }) else {
            return
        }

        wishes[index] = wishes[index].preparedForContentUpdate(
            title: wish.title,
            detail: wish.detail,
            note: wish.note,
            category: wish.category,
            status: wish.status,
            targetText: wish.targetText,
            symbol: wish.symbol,
            scope: scope
        )
        save()
    }

    func delete(_ wishID: UUID, in scope: AppContentScope) {
        let originalCount = wishes.count
        wishes.removeAll { $0.id == wishID && $0.matches(scope: scope) }
        guard wishes.count != originalCount else { return }
        save()
    }

    func replaceWishes(in scope: AppContentScope, with importedWishes: [PlaceWish]) {
        wishes.removeAll { $0.matches(scope: scope) }
        wishes.append(contentsOf: importedWishes.map { $0.preparedForScopeReplacement(in: scope) })
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            wishes = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredWish].self, from: data)
            wishes = decoded.map(\.model)
        } catch {
            wishes = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(wishes.map { StoredWish(wish: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save wishes: \(error)")
        }
    }
}

@MainActor
final class AnniversaryStore: ObservableObject {
    @Published private(set) var anniversaries: [AnniversaryItem] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.anniversaries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var hasPersistedAnniversaries: Bool {
        !anniversaries.isEmpty
    }

    func anniversaries(in scope: AppContentScope) -> [AnniversaryItem] {
        anniversaries
            .filter { $0.matches(scope: scope) }
            .sorted(by: AnniversaryItem.reminderSort(_:_:))
    }

    func add(_ item: AnniversaryItem, in scope: AppContentScope) {
        anniversaries.append(item.preparedForLocalInsert(in: scope))
        anniversaries.sort(by: AnniversaryItem.reminderSort(_:_:))
        save()
    }

    func update(_ item: AnniversaryItem, in scope: AppContentScope) {
        guard let index = anniversaries.firstIndex(where: { $0.id == item.id && $0.matches(scope: scope) }) else {
            return
        }

        anniversaries[index] = anniversaries[index].preparedForContentUpdate(
            title: item.title,
            date: item.date,
            category: item.category,
            note: item.note,
            cadence: item.cadence,
            scope: scope
        )
        anniversaries.sort(by: AnniversaryItem.reminderSort(_:_:))
        save()
    }

    func delete(_ itemID: UUID, in scope: AppContentScope) {
        let originalCount = anniversaries.count
        anniversaries.removeAll { $0.id == itemID && $0.matches(scope: scope) }
        guard anniversaries.count != originalCount else { return }
        save()
    }

    func replaceAnniversaries(in scope: AppContentScope, with importedItems: [AnniversaryItem]) {
        anniversaries.removeAll { $0.matches(scope: scope) }
        anniversaries.append(contentsOf: importedItems.map { $0.preparedForScopeReplacement(in: scope) })
        anniversaries.sort(by: AnniversaryItem.reminderSort(_:_:))
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            anniversaries = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredAnniversary].self, from: data)
            anniversaries = decoded
                .map(\.model)
                .sorted(by: AnniversaryItem.reminderSort(_:_:))
        } catch {
            anniversaries = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(anniversaries.map { StoredAnniversary(item: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save anniversaries: \(error)")
        }
    }
}

@MainActor
final class WeeklyTodoStore: ObservableObject {
    @Published private(set) var items: [WeeklyTodoItem] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.weeklyTodoItems"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func items(in scope: AppContentScope) -> [WeeklyTodoItem] {
        self.items
            .filter { $0.matches(scope: scope) }
            .sorted(by: WeeklyTodoStore.compareItems(_:_:))
    }

    func add(_ item: WeeklyTodoItem, in scope: AppContentScope) {
        items.append(item.preparedForLocalInsert(in: scope))
        items.sort(by: WeeklyTodoStore.compareItems(_:_:))
        save()
    }

    func setCompletion(_ isCompleted: Bool, for itemID: UUID, in scope: AppContentScope) {
        guard let index = items.firstIndex(where: { $0.id == itemID && $0.matches(scope: scope) }) else {
            return
        }

        items[index] = items[index].preparedForCompletionMutation(
            isCompleted: isCompleted,
            scope: scope
        )
        items.sort(by: WeeklyTodoStore.compareItems(_:_:))
        save()
    }

    func update(_ item: WeeklyTodoItem, in scope: AppContentScope) {
        guard let index = items.firstIndex(where: { $0.id == item.id && $0.matches(scope: scope) }) else {
            return
        }

        items[index] = items[index].preparedForContentUpdate(
            title: item.title,
            scheduledDate: item.scheduledDate,
            owner: item.owner,
            scope: scope
        )
        items.sort(by: WeeklyTodoStore.compareItems(_:_:))
        save()
    }

    func delete(_ itemID: UUID, in scope: AppContentScope) {
        let originalCount = items.count
        items.removeAll { $0.id == itemID && $0.matches(scope: scope) }
        guard items.count != originalCount else { return }
        save()
    }

    func replaceItems(in scope: AppContentScope, with importedItems: [WeeklyTodoItem]) {
        items.removeAll { $0.matches(scope: scope) }
        items.append(contentsOf: importedItems.map { $0.preparedForScopeReplacement(in: scope) })
        items.sort(by: WeeklyTodoStore.compareItems(_:_:))
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredWeeklyTodo].self, from: data)
            items = decoded.map(\.model).sorted(by: WeeklyTodoStore.compareItems(_:_:))
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items.map { StoredWeeklyTodo(item: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save weekly todo items: \(error)")
        }
    }

    private static func compareItems(_ lhs: WeeklyTodoItem, _ rhs: WeeklyTodoItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return lhs.isCompleted == false
        }

        switch (lhs.scheduledDate, rhs.scheduledDate) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.createdAt > rhs.createdAt
    }
}

@MainActor
final class TonightDinnerStore: ObservableObject {
    @Published private(set) var items: [TonightDinnerOption] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.tonightDinnerOptions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func items(in scope: AppContentScope) -> [TonightDinnerOption] {
        self.items
            .filter { $0.matches(scope: scope) }
            .map { $0.normalizedForCurrentDay() }
            .sorted(by: Self.compareItems(_:_:))
    }

    func add(_ item: TonightDinnerOption, in scope: AppContentScope) {
        items.append(item.preparedForLocalInsert(in: scope))
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func choose(_ itemID: UUID, in scope: AppContentScope) {
        var didMutate = false

        items = items.map { item in
            guard item.matches(scope: scope) else { return item }

            if item.id == itemID {
                didMutate = true
                return item.preparedForSelectionMutation(status: .chosen, scope: scope)
            }

            if item.status == .chosen {
                didMutate = true
                return item.preparedForSelectionMutation(status: .candidate, scope: scope)
            }

            return item
        }

        guard didMutate else { return }
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func update(_ item: TonightDinnerOption, in scope: AppContentScope) {
        guard let index = items.firstIndex(where: { $0.id == item.id && $0.matches(scope: scope) }) else {
            return
        }

        items[index] = items[index].preparedForContentUpdate(
            title: item.title,
            note: item.note,
            scope: scope
        )
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func delete(_ itemID: UUID, in scope: AppContentScope) {
        let originalCount = items.count
        items.removeAll { $0.id == itemID && $0.matches(scope: scope) }
        guard items.count != originalCount else { return }
        save()
    }

    func replaceItems(in scope: AppContentScope, with importedItems: [TonightDinnerOption]) {
        items.removeAll { $0.matches(scope: scope) }
        items.append(contentsOf: importedItems.map { $0.preparedForScopeReplacement(in: scope) })
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredTonightDinnerOption].self, from: data)
            items = decoded.map(\.model).sorted(by: Self.compareItems(_:_:))
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items.map { StoredTonightDinnerOption(item: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save tonight dinner options: \(error)")
        }
    }

    private static func compareItems(_ lhs: TonightDinnerOption, _ rhs: TonightDinnerOption) -> Bool {
        if lhs.status != rhs.status {
            return lhs.status == .chosen
        }

        if let lhsDecidedAt = lhs.decidedAt, let rhsDecidedAt = rhs.decidedAt, lhsDecidedAt != rhsDecidedAt {
            return lhsDecidedAt > rhsDecidedAt
        }

        return lhs.createdAt > rhs.createdAt
    }
}

@MainActor
final class RitualStore: ObservableObject {
    @Published private(set) var items: [RitualItem] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.ritualItems"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func items(in scope: AppContentScope) -> [RitualItem] {
        self.items
            .filter { $0.matches(scope: scope) }
            .sorted(by: Self.compareItems(_:_:))
    }

    func add(_ item: RitualItem, in scope: AppContentScope) {
        items.append(item.preparedForLocalInsert(in: scope))
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func setCompletion(_ isCompleted: Bool, for itemID: UUID, in scope: AppContentScope) {
        guard let index = items.firstIndex(where: { $0.id == itemID && $0.matches(scope: scope) }) else {
            return
        }

        items[index] = items[index].preparedForCompletionMutation(
            isCompleted: isCompleted,
            scope: scope
        )
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func update(_ item: RitualItem, in scope: AppContentScope) {
        guard let index = items.firstIndex(where: { $0.id == item.id && $0.matches(scope: scope) }) else {
            return
        }

        items[index] = items[index].preparedForContentUpdate(
            title: item.title,
            kind: item.kind,
            note: item.note,
            scope: scope
        )
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func delete(_ itemID: UUID, in scope: AppContentScope) {
        let originalCount = items.count
        items.removeAll { $0.id == itemID && $0.matches(scope: scope) }
        guard items.count != originalCount else { return }
        save()
    }

    func replaceItems(in scope: AppContentScope, with importedItems: [RitualItem]) {
        items.removeAll { $0.matches(scope: scope) }
        items.append(contentsOf: importedItems.map { $0.preparedForScopeReplacement(in: scope) })
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredRitualItem].self, from: data)
            items = decoded.map(\.model).sorted(by: Self.compareItems(_:_:))
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items.map { StoredRitualItem(item: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save ritual items: \(error)")
        }
    }

    private static func compareItems(_ lhs: RitualItem, _ rhs: RitualItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return lhs.isCompleted == false
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.createdAt > rhs.createdAt
    }
}

@MainActor
final class CurrentStatusStore: ObservableObject {
    @Published private(set) var items: [CurrentStatusItem] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.currentStatuses"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func status(for userID: String, in scope: AppContentScope) -> CurrentStatusItem? {
        items(in: scope)
            .filter { $0.userId == userID }
            .max { $0.updatedAt < $1.updatedAt }
    }

    func items(in scope: AppContentScope) -> [CurrentStatusItem] {
        self.items
            .filter { $0.matches(scope: scope) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsert(
        displayText: String,
        tone: StatusTone,
        effectiveScope: CurrentStatusEffectiveScope,
        for userID: String,
        in scope: AppContentScope
    ) {
        let normalizedText = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        if let index = items.firstIndex(where: { $0.userId == userID && $0.matches(scope: scope) }) {
            let existing = items[index]
            items[index] = CurrentStatusItem(
                id: existing.id,
                userId: userID,
                displayText: normalizedText,
                tone: tone,
                effectiveScope: effectiveScope,
                spaceId: scope.spaceId,
                updatedAt: .now
            )
        } else {
            items.append(
                CurrentStatusItem(
                    userId: userID,
                    displayText: normalizedText,
                    tone: tone,
                    effectiveScope: effectiveScope,
                    spaceId: scope.spaceId,
                    updatedAt: .now
                )
            )
        }

        items.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    func clearStatus(for userID: String, in scope: AppContentScope) {
        let originalCount = items.count
        items.removeAll { $0.userId == userID && $0.matches(scope: scope) }
        guard items.count != originalCount else { return }
        save()
    }

    func replaceStatuses(in scope: AppContentScope, with importedItems: [CurrentStatusItem]) {
        items.removeAll { $0.matches(scope: scope) }
        items.append(contentsOf: importedItems.map { $0.preparedForScopeReplacement(in: scope) })
        items.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredCurrentStatus].self, from: data)
            items = decoded.map(\.model).sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items.map { StoredCurrentStatus(item: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save current statuses: \(error)")
        }
    }
}

@MainActor
final class WhisperNoteStore: ObservableObject {
    @Published private(set) var items: [WhisperNoteItem] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.whisperNotes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func items(in scope: AppContentScope) -> [WhisperNoteItem] {
        self.items
            .filter { $0.matches(scope: scope) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ item: WhisperNoteItem, in scope: AppContentScope) {
        items.append(item.preparedForLocalInsert(in: scope))
        items.sort { $0.createdAt > $1.createdAt }
        save()
    }

    func update(_ item: WhisperNoteItem, in scope: AppContentScope) {
        guard let index = items.firstIndex(where: { $0.id == item.id && $0.matches(scope: scope) }) else {
            return
        }

        items[index] = items[index].preparedForContentUpdate(
            content: item.content,
            scope: scope
        )
        items.sort { $0.createdAt > $1.createdAt }
        save()
    }

    func delete(_ itemID: UUID, in scope: AppContentScope) {
        let originalCount = items.count
        items.removeAll { $0.id == itemID && $0.matches(scope: scope) }
        guard items.count != originalCount else { return }
        save()
    }

    func replaceItems(in scope: AppContentScope, with importedItems: [WhisperNoteItem]) {
        let beforeMatchingCount = items.filter { $0.matches(scope: scope) }.count
        items.removeAll { $0.matches(scope: scope) }
        items.append(contentsOf: importedItems.map { $0.preparedForScopeReplacement(in: scope) })
        items.sort { $0.createdAt > $1.createdAt }
        let afterMatchingCount = items.filter { $0.matches(scope: scope) }.count
#if DEBUG
        print(
            "[WhisperSync] store replace space=\(scope.spaceId) imported=\(importedItems.count) beforeMatching=\(beforeMatchingCount) afterMatching=\(afterMatchingCount)"
        )
#endif
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([StoredWhisperNote].self, from: data)
            items = decoded.map(\.model).sorted { $0.createdAt > $1.createdAt }
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items.map { StoredWhisperNote(item: $0) })
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save whisper notes: \(error)")
        }
    }
}

private struct StoredMemoryEntry: Codable {
    let id: UUID
    let title: String
    let detail: String
    let date: Date
    let categoryRawValue: String
    let imageLabel: String
    let photoFilename: String?
    let mood: String
    let location: String
    let weather: String
    let isFeatured: Bool
    let spaceId: String?
    let createdByUserId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let syncStatusRawValue: String?

    init(entry: MemoryTimelineEntry) {
        id = entry.id
        title = entry.title
        detail = entry.detail
        date = entry.date
        categoryRawValue = entry.category.rawValue
        imageLabel = entry.imageLabel
        photoFilename = entry.photoFilename
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
        let resolvedCreatedAt = createdAt ?? date
        return MemoryTimelineEntry(
            id: id,
            title: title,
            detail: detail,
            date: date,
            category: MemoryCategory(rawValue: categoryRawValue) ?? .daily,
            imageLabel: imageLabel,
            photoFilename: photoFilename,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            createdAt: resolvedCreatedAt,
            updatedAt: updatedAt ?? resolvedCreatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

enum MemoryPhotoStorageError: LocalizedError {
    case invalidImageData
    case inaccessibleStorageDirectory
    case failedToWriteImage

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "这张图片暂时无法读取，请换一张再试。"
        case .inaccessibleStorageDirectory:
            return "图片保存目录暂时不可用，请稍后再试。"
        case .failedToWriteImage:
            return "图片暂时没有保存成功，请重新试一次。"
        }
    }
}

enum MemoryPhotoStorage {
    private static let folderName = "MemoryPhotos"

    static func saveImageData(_ data: Data, for entryID: UUID) throws -> String {
        guard let image = UIImage(data: data) else {
            throw MemoryPhotoStorageError.invalidImageData
        }

        guard let normalizedData = image.jpegData(compressionQuality: 0.86) else {
            throw MemoryPhotoStorageError.invalidImageData
        }

        let filename = "memory-\(entryID.uuidString.lowercased()).jpg"
        let destinationURL = try directoryURL().appendingPathComponent(filename, isDirectory: false)

        do {
            try normalizedData.write(to: destinationURL, options: .atomic)
            return filename
        } catch {
            throw MemoryPhotoStorageError.failedToWriteImage
        }
    }

    static func imageURL(for filename: String?) -> URL? {
        guard let filename else { return nil }
        let normalizedFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedFilename.isEmpty else { return nil }
        return try? directoryURL().appendingPathComponent(normalizedFilename, isDirectory: false)
    }

    static func imageData(for filename: String?) -> Data? {
        guard let url = imageURL(for: filename) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func uiImage(for filename: String?) -> UIImage? {
        guard let url = imageURL(for: filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func deleteImage(for filename: String?) {
        guard let url = imageURL(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func directoryURL() throws -> URL {
        let fileManager = FileManager.default
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MemoryPhotoStorageError.inaccessibleStorageDirectory
        }

        let directoryURL = baseURL.appendingPathComponent(folderName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return directoryURL
        } catch {
            throw MemoryPhotoStorageError.inaccessibleStorageDirectory
        }
    }
}

private struct StoredWish: Codable {
    let id: UUID
    let title: String
    let detail: String
    let note: String
    let categoryRawValue: String
    let statusRawValue: String
    let targetText: String
    let symbol: String
    let spaceId: String?
    let createdByUserId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let syncStatusRawValue: String?

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
        let resolvedCreatedAt = createdAt ?? .now
        return PlaceWish(
            id: id,
            title: title,
            detail: detail,
            note: note,
            category: WishCategory(rawValue: categoryRawValue) ?? .date,
            status: WishStatus(rawValue: statusRawValue) ?? .dreaming,
            targetText: targetText,
            symbol: symbol,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            createdAt: resolvedCreatedAt,
            updatedAt: updatedAt ?? resolvedCreatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private struct StoredAnniversary: Codable {
    let id: UUID
    let title: String
    let date: Date
    let categoryRawValue: String
    let note: String
    let cadenceRawValue: String
    let spaceId: String?
    let createdByUserId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let syncStatusRawValue: String?

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
        let resolvedCreatedAt = createdAt ?? date
        return AnniversaryItem(
            id: id,
            title: title,
            date: date,
            category: AnniversaryCategory(rawValue: categoryRawValue) ?? .custom,
            note: note,
            cadence: AnniversaryCadence(rawValue: cadenceRawValue) ?? .yearly,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            createdAt: resolvedCreatedAt,
            updatedAt: updatedAt ?? resolvedCreatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private struct StoredWeeklyTodo: Codable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let scheduledDate: Date?
    let ownerRawValue: String?
    let spaceId: String?
    let createdByUserId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let syncStatusRawValue: String?

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
        let resolvedCreatedAt = createdAt ?? .now
        return WeeklyTodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: ownerRawValue.flatMap(WeeklyTodoOwner.init(rawValue:)),
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            createdAt: resolvedCreatedAt,
            updatedAt: updatedAt ?? resolvedCreatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private struct StoredRitualItem: Codable {
    let id: UUID
    let title: String
    let kindRawValue: String?
    let isCompleted: Bool
    let note: String?
    let createdAt: Date?
    let updatedAt: Date?
    let createdByUserId: String?
    let spaceId: String?
    let syncStatusRawValue: String?

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
        let resolvedCreatedAt = createdAt ?? .now
        return RitualItem(
            id: id,
            title: title,
            kind: RitualKind(rawValue: kindRawValue ?? "") ?? .promise,
            isCompleted: isCompleted,
            note: note ?? "",
            createdAt: resolvedCreatedAt,
            updatedAt: updatedAt ?? resolvedCreatedAt,
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private struct StoredTonightDinnerOption: Codable {
    let id: UUID
    let title: String
    let note: String
    let statusRawValue: String
    let createdAt: Date
    let decidedAt: Date?
    let createdByUserId: String?
    let spaceId: String?
    let syncStatusRawValue: String?

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
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private struct StoredCurrentStatus: Codable {
    let id: UUID
    let userId: String
    let displayText: String
    let toneRawValue: String
    let effectiveScopeRawValue: String
    let spaceId: String?
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
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            updatedAt: updatedAt
        )
    }
}

private struct StoredWhisperNote: Codable {
    let id: UUID
    let content: String
    let createdAt: Date
    let createdByUserId: String?
    let spaceId: String?
    let syncStatusRawValue: String?

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
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private extension MemoryTimelineEntry {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> MemoryTimelineEntry {
        return MemoryTimelineEntry(
            id: id,
            title: title,
            detail: detail,
            date: date,
            category: category,
            imageLabel: imageLabel,
            photoFilename: photoFilename,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: .localOnly
        )
    }

    func scopedToSeed(_ scope: AppContentScope) -> MemoryTimelineEntry {
        return MemoryTimelineEntry(
            id: id,
            title: title,
            detail: detail,
            date: date,
            category: category,
            imageLabel: imageLabel,
            photoFilename: photoFilename,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .localOnly
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> MemoryTimelineEntry {
        return MemoryTimelineEntry(
            id: id,
            title: title,
            detail: detail,
            date: date,
            category: category,
            imageLabel: imageLabel,
            photoFilename: photoFilename,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }

    func preparedForContentUpdate(
        title: String,
        body: String,
        date: Date,
        category: MemoryCategory,
        imageLabel: String,
        photoFilename: String?,
        mood: String,
        location: String,
        weather: String,
        scope: AppContentScope
    ) -> MemoryTimelineEntry {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return MemoryTimelineEntry(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            category: category,
            imageLabel: imageLabel,
            photoFilename: photoFilename,
            mood: mood.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            weather: weather.trimmingCharacters(in: .whitespacesAndNewlines),
            isFeatured: isFeatured,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: nextSyncStatus
        )
    }
}

private extension PlaceWish {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> PlaceWish {
        return PlaceWish(
            id: id,
            title: title,
            detail: detail,
            note: note,
            category: category,
            status: status,
            targetText: targetText,
            symbol: symbol,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: .localOnly
        )
    }

    func scopedToSeed(_ scope: AppContentScope) -> PlaceWish {
        return PlaceWish(
            id: id,
            title: title,
            detail: detail,
            note: note,
            category: category,
            status: status,
            targetText: targetText,
            symbol: symbol,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .localOnly
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> PlaceWish {
        return PlaceWish(
            id: id,
            title: title,
            detail: detail,
            note: note,
            category: category,
            status: status,
            targetText: targetText,
            symbol: symbol,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }

    func preparedForContentUpdate(
        title: String,
        detail: String,
        note: String,
        category: WishCategory,
        status: WishStatus,
        targetText: String,
        symbol: String,
        scope: AppContentScope
    ) -> PlaceWish {
        PlaceWish(
            id: id,
            title: title,
            detail: detail,
            note: note,
            category: category,
            status: status,
            targetText: targetText,
            symbol: symbol,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: .localOnly
        )
    }
}

private extension AnniversaryItem {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> AnniversaryItem {
        return AnniversaryItem(
            id: id,
            title: title,
            date: date,
            category: category,
            note: note,
            cadence: cadence,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: .localOnly
        )
    }

    func scopedToSeed(_ scope: AppContentScope) -> AnniversaryItem {
        return AnniversaryItem(
            id: id,
            title: title,
            date: date,
            category: category,
            note: note,
            cadence: cadence,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .localOnly
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> AnniversaryItem {
        return AnniversaryItem(
            id: id,
            title: title,
            date: date,
            category: category,
            note: note,
            cadence: cadence,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }

    func preparedForContentUpdate(
        title: String,
        date: Date,
        category: AnniversaryCategory,
        note: String,
        cadence: AnniversaryCadence,
        scope: AppContentScope
    ) -> AnniversaryItem {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return AnniversaryItem(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: Calendar.current.startOfDay(for: date),
            category: category,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            cadence: cadence,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: nextSyncStatus
        )
    }
}

private extension WeeklyTodoItem {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> WeeklyTodoItem {
        WeeklyTodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: owner,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: .localOnly
        )
    }

    func preparedForCompletionMutation(
        isCompleted: Bool,
        scope: AppContentScope
    ) -> WeeklyTodoItem {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return WeeklyTodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: owner,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: nextSyncStatus
        )
    }

    func preparedForContentUpdate(
        title: String,
        scheduledDate: Date?,
        owner: WeeklyTodoOwner?,
        scope: AppContentScope
    ) -> WeeklyTodoItem {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return WeeklyTodoItem(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: owner,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: .now,
            syncStatus: nextSyncStatus
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> WeeklyTodoItem {
        WeeklyTodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: owner,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }
}

private extension RitualItem {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> RitualItem {
        RitualItem(
            id: id,
            title: title,
            kind: kind,
            isCompleted: false,
            note: note,
            createdAt: createdAt,
            updatedAt: .now,
            createdByUserId: scope.currentUserId,
            spaceId: scope.spaceId,
            syncStatus: .localOnly
        )
    }

    func preparedForCompletionMutation(
        isCompleted: Bool,
        scope: AppContentScope
    ) -> RitualItem {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return RitualItem(
            id: id,
            title: title,
            kind: kind,
            isCompleted: isCompleted,
            note: note,
            createdAt: createdAt,
            updatedAt: .now,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: nextSyncStatus
        )
    }

    func preparedForContentUpdate(
        title: String,
        kind: RitualKind,
        note: String,
        scope: AppContentScope
    ) -> RitualItem {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return RitualItem(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            isCompleted: isCompleted,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt,
            updatedAt: .now,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: nextSyncStatus
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> RitualItem {
        RitualItem(
            id: id,
            title: title,
            kind: kind,
            isCompleted: isCompleted,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: syncStatus
        )
    }
}

private extension TonightDinnerOption {
    func normalizedForCurrentDay(referenceDate: Date = .now) -> TonightDinnerOption {
        guard status == .chosen, let decidedAt else { return self }
        guard !Calendar.current.isDate(decidedAt, inSameDayAs: referenceDate) else { return self }

        return TonightDinnerOption(
            id: id,
            title: title,
            note: note,
            status: .candidate,
            createdAt: createdAt,
            decidedAt: nil,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: syncStatus
        )
    }

    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> TonightDinnerOption {
        TonightDinnerOption(
            id: id,
            title: title,
            note: note,
            status: .candidate,
            createdAt: createdAt,
            decidedAt: nil,
            createdByUserId: scope.currentUserId,
            spaceId: scope.spaceId,
            syncStatus: .localOnly
        )
    }

    func preparedForSelectionMutation(
        status: TonightDinnerStatus,
        scope: AppContentScope
    ) -> TonightDinnerOption {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return TonightDinnerOption(
            id: id,
            title: title,
            note: note,
            status: status,
            createdAt: createdAt,
            decidedAt: status == .chosen ? .now : nil,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: nextSyncStatus
        )
    }

    func preparedForContentUpdate(
        title: String,
        note: String,
        scope: AppContentScope
    ) -> TonightDinnerOption {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return TonightDinnerOption(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            createdAt: createdAt,
            decidedAt: decidedAt,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: nextSyncStatus
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> TonightDinnerOption {
        TonightDinnerOption(
            id: id,
            title: title,
            note: note,
            status: status,
            createdAt: createdAt,
            decidedAt: decidedAt,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: syncStatus
        )
    }
}

private extension CurrentStatusItem {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> CurrentStatusItem {
        CurrentStatusItem(
            id: id,
            userId: userId,
            displayText: displayText,
            tone: tone,
            effectiveScope: effectiveScope,
            spaceId: scope.spaceId,
            updatedAt: updatedAt
        )
    }
}

private extension WhisperNoteItem {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> WhisperNoteItem {
        WhisperNoteItem(
            id: id,
            content: content,
            createdAt: .now,
            createdByUserId: scope.currentUserId,
            spaceId: scope.spaceId,
            syncStatus: .localOnly
        )
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> WhisperNoteItem {
        WhisperNoteItem(
            id: id,
            content: content,
            createdAt: createdAt,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: syncStatus
        )
    }

    func preparedForContentUpdate(
        content: String,
        scope: AppContentScope
    ) -> WhisperNoteItem {
        let nextSyncStatus: SyncStatus
        switch syncStatus {
        case .synced:
            nextSyncStatus = .pendingUpload
        case .pendingUpload:
            nextSyncStatus = .pendingUpload
        case .localOnly:
            nextSyncStatus = .localOnly
        }

        return WhisperNoteItem(
            id: id,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: nextSyncStatus
        )
    }
}
