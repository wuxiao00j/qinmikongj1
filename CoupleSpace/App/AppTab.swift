import Combine
import Foundation
import UIKit

#if DEBUG
private func debugMemoryStore(_ message: @autoclosure () -> String) {
    print("[MemoryStore] \(message())")
}

private func debugWishStore(_ message: @autoclosure () -> String) {
    print("[WishStore] \(message())")
}
#else
private func debugMemoryStore(_ message: @autoclosure () -> String) {}
private func debugWishStore(_ message: @autoclosure () -> String) {}
#endif

private func makeWishStoreJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = formatter.date(from: value) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        if let date = fallbackFormatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date: \(value)"
        )
    }
    return decoder
}

private func makeWishStoreJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(formatter.string(from: date))
    }
    return encoder
}

private func wishFieldResolutionTime(_ explicitDate: Date?, fallback wish: PlaceWish) -> Date {
    explicitDate ?? wish.updatedAt
}

private func resolveWishField<Value>(
    localValue: Value,
    localUpdatedAt: Date,
    remoteValue: Value,
    remoteUpdatedAt: Date,
    localWish: PlaceWish,
    remoteWish: PlaceWish
) -> (Value, Date) {
    if remoteUpdatedAt > localUpdatedAt {
        return (remoteValue, remoteUpdatedAt)
    }
    if remoteUpdatedAt < localUpdatedAt {
        return (localValue, localUpdatedAt)
    }
    if remoteWish.updatedAt > localWish.updatedAt {
        return (remoteValue, remoteUpdatedAt)
    }
    if remoteWish.updatedAt < localWish.updatedAt {
        return (localValue, localUpdatedAt)
    }
    return (localValue, localUpdatedAt)
}

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
    @Published private(set) var deletionTombstones: [MemoryDeletionTombstone] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.memoryEntries"
    private let deletionStorageKey = "com.barry.CoupleSpace.memoryDeletionTombstones"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var hasPersistedEntries: Bool {
        !entries.isEmpty || !deletionTombstones.isEmpty
    }

    func entries(in scope: AppContentScope) -> [MemoryTimelineEntry] {
        let deletedIDs = Set(deletionTombstones(in: scope).map(\.id))
        return entries
            .filter { $0.matches(scope: scope) && deletedIDs.contains($0.id) == false }
            .sorted { $0.date > $1.date }
    }

    func deletionTombstones(in scope: AppContentScope) -> [MemoryDeletionTombstone] {
        deletionTombstones
            .filter { $0.matches(scope: scope) }
            .sorted { $0.deletedAt > $1.deletedAt }
    }

    func add(_ entry: MemoryTimelineEntry, in scope: AppContentScope) {
        let preparedEntry = entry.preparedForLocalInsert(in: scope)
        debugMemoryStore(
            "local add id=\(preparedEntry.id.uuidString.lowercased()) user=\(preparedEntry.createdByUserId) space=\(preparedEntry.spaceId) updatedAt=\(preparedEntry.updatedAt.timeIntervalSince1970)"
        )
        entries.append(preparedEntry)
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

        debugMemoryStore(
            "local update id=\(updatedEntry.id.uuidString.lowercased()) user=\(updatedEntry.createdByUserId) space=\(updatedEntry.spaceId) updatedAt=\(updatedEntry.updatedAt.timeIntervalSince1970)"
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

        debugMemoryStore(
            "local delete id=\(existingEntry.id.uuidString.lowercased()) user=\(existingEntry.createdByUserId) space=\(existingEntry.spaceId) updatedAt=\(existingEntry.updatedAt.timeIntervalSince1970)"
        )
        entries.removeAll { $0.id == entryID && $0.matches(scope: scope) }
        upsertDeletionTombstone(
            MemoryDeletionTombstone(
                id: entryID,
                spaceId: scope.spaceId,
                deletedByUserId: scope.currentUserId
            ),
            in: scope
        )
        MemoryPhotoStorage.deleteImage(for: existingEntry.photoFilename)
        save()
    }

    func replaceEntries(in scope: AppContentScope, with importedEntries: [MemoryTimelineEntry]) {
        let deletedIDs = Set(deletionTombstones(in: scope).map(\.id))
        let localBeforeEntries = entries.filter { $0.matches(scope: scope) }
        let existingEntriesByID = Dictionary(
            uniqueKeysWithValues: entries
                .filter { $0.matches(scope: scope) }
                .map { ($0.id, $0) }
        )
        debugMemoryStore(
            "replace begin space=\(scope.spaceId) localBefore=\(localBeforeEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ",")) imported=\(importedEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ",")) deleted=\(deletedIDs.map { $0.uuidString.lowercased() }.sorted().joined(separator: ","))"
        )
        entries.removeAll { $0.matches(scope: scope) }
        entries.append(
            contentsOf: importedEntries.filter { deletedIDs.contains($0.id) == false }.map {
                $0.preparedForScopeReplacement(
                    in: scope,
                    preservingLocalImageMetadataFrom: existingEntriesByID[$0.id]
                )
            }
        )
        entries.sort { $0.date > $1.date }
        let localAfterEntries = entries.filter { $0.matches(scope: scope) }
        let localAfterIDs = Set(localAfterEntries.map(\.id))
        let removedEntries = localBeforeEntries.filter { localAfterIDs.contains($0.id) == false }
        if removedEntries.isEmpty == false {
            let removedSummary = removedEntries.map {
                "\($0.id.uuidString.lowercased())|user=\($0.createdByUserId)|updatedAt=\($0.updatedAt.timeIntervalSince1970)"
            }.joined(separator: ",")
            debugMemoryStore(
                "replace removed space=\(scope.spaceId) ids=\(removedSummary)"
            )
        }
        debugMemoryStore(
            "replace end space=\(scope.spaceId) localAfter=\(localAfterEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ","))"
        )
        save()
    }

    func mergeRemoteEntries(in scope: AppContentScope, with importedEntries: [MemoryTimelineEntry]) {
        let deletedIDs = Set(deletionTombstones(in: scope).map(\.id))
        let localBeforeEntries = entries.filter { $0.matches(scope: scope) }
        let localBeforeByID = Dictionary(uniqueKeysWithValues: localBeforeEntries.map { ($0.id, $0) })
        var mergedByID = Dictionary(
            uniqueKeysWithValues: localBeforeEntries
                .filter { deletedIDs.contains($0.id) == false }
                .map { ($0.id, $0) }
        )

        debugMemoryStore(
            "merge remote begin space=\(scope.spaceId) localBefore=\(localBeforeEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ",")) imported=\(importedEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ",")) deleted=\(deletedIDs.map { $0.uuidString.lowercased() }.sorted().joined(separator: ","))"
        )

        for importedEntry in importedEntries {
            guard deletedIDs.contains(importedEntry.id) == false else { continue }

            let preparedEntry = importedEntry.preparedForScopeReplacement(
                in: scope,
                preservingLocalImageMetadataFrom: localBeforeByID[importedEntry.id]
            )

            if let existingEntry = mergedByID[preparedEntry.id] {
                if existingEntry.updatedAt > preparedEntry.updatedAt {
                    debugMemoryStore(
                        "merge remote keep newer local space=\(scope.spaceId) id=\(existingEntry.id.uuidString.lowercased()) localUpdatedAt=\(existingEntry.updatedAt.timeIntervalSince1970) remoteUpdatedAt=\(preparedEntry.updatedAt.timeIntervalSince1970)"
                    )
                    continue
                }

                debugMemoryStore(
                    "merge remote upsert space=\(scope.spaceId) id=\(preparedEntry.id.uuidString.lowercased()) localUpdatedAt=\(existingEntry.updatedAt.timeIntervalSince1970) remoteUpdatedAt=\(preparedEntry.updatedAt.timeIntervalSince1970)"
                )
            } else {
                debugMemoryStore(
                    "merge remote insert space=\(scope.spaceId) id=\(preparedEntry.id.uuidString.lowercased()) remoteUpdatedAt=\(preparedEntry.updatedAt.timeIntervalSince1970)"
                )
            }

            mergedByID[preparedEntry.id] = preparedEntry
        }

        entries.removeAll { $0.matches(scope: scope) }
        entries.append(contentsOf: mergedByID.values)
        entries.sort { $0.date > $1.date }

        let localAfterEntries = entries.filter { $0.matches(scope: scope) }
        let localAfterIDs = Set(localAfterEntries.map(\.id))
        let removedEntries = localBeforeEntries.filter { localAfterIDs.contains($0.id) == false }
        if removedEntries.isEmpty == false {
            let removedSummary = removedEntries.map {
                "\($0.id.uuidString.lowercased())|user=\($0.createdByUserId)|updatedAt=\($0.updatedAt.timeIntervalSince1970)"
            }.joined(separator: ",")
            debugMemoryStore(
                "merge remote removed space=\(scope.spaceId) ids=\(removedSummary)"
            )
        }
        debugMemoryStore(
            "merge remote end space=\(scope.spaceId) localAfter=\(localAfterEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ","))"
        )
        save()
    }

    @discardableResult
    func mergeDeletionTombstones(
        in scope: AppContentScope,
        with importedTombstones: [MemoryDeletionTombstone]
    ) -> [MemoryDeletionTombstone] {
        let keptTombstones = deletionTombstones.filter { !$0.matches(scope: scope) }
        var mergedByID = Dictionary(
            uniqueKeysWithValues: deletionTombstones(in: scope).map { ($0.id, $0) }
        )

        for tombstone in importedTombstones {
            guard tombstone.matches(scope: scope) else { continue }
            if let existing = mergedByID[tombstone.id], existing.deletedAt >= tombstone.deletedAt {
                continue
            }
            mergedByID[tombstone.id] = tombstone.preparedForScopeReplacement(in: scope)
        }

        let mergedTombstones = mergedByID.values.sorted { $0.deletedAt > $1.deletedAt }
        deletionTombstones = keptTombstones + mergedTombstones

        let deletedIDs = Set(mergedTombstones.map(\.id))
        let removedEntries = entries.filter { $0.matches(scope: scope) && deletedIDs.contains($0.id) }
        if removedEntries.isEmpty == false {
            debugMemoryStore(
                "merge tombstones removed entries space=\(scope.spaceId) tombstones=\(mergedTombstones.map { $0.id.uuidString.lowercased() }.joined(separator: ",")) removed=\(removedEntries.map { $0.id.uuidString.lowercased() }.joined(separator: ","))"
            )
            removedEntries.forEach { MemoryPhotoStorage.deleteImage(for: $0.photoFilename) }
            entries.removeAll { $0.matches(scope: scope) && deletedIDs.contains($0.id) }
            entries.sort { $0.date > $1.date }
        }

        save()
        return mergedTombstones
    }

    func setRemoteAssetID(_ remoteAssetID: String?, for entryID: UUID, in scope: AppContentScope) {
        guard let index = entries.firstIndex(where: { $0.id == entryID && $0.matches(scope: scope) }) else {
            return
        }

        let normalizedRemoteAssetID = remoteAssetID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedRemoteAssetID = normalizedRemoteAssetID?.isEmpty == false ? normalizedRemoteAssetID : nil
        guard entries[index].remoteAssetID != resolvedRemoteAssetID else { return }

        let entry = entries[index]
        entries[index] = MemoryTimelineEntry(
            id: entry.id,
            title: entry.title,
            body: entry.body,
            date: entry.date,
            category: entry.category,
            imageLabel: entry.imageLabel,
            photoFilename: entry.photoFilename,
            remoteAssetID: resolvedRemoteAssetID,
            mood: entry.mood,
            location: entry.location,
            weather: entry.weather,
            isFeatured: entry.isFeatured,
            spaceId: entry.spaceId,
            createdByUserId: entry.createdByUserId,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            syncStatus: entry.syncStatus
        )
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            entries = []
            loadDeletionTombstones()
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

        loadDeletionTombstones()
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries.map { StoredMemoryEntry(entry: $0) })
            defaults.set(data, forKey: storageKey)
            let tombstoneData = try encoder.encode(
                deletionTombstones.map { StoredMemoryDeletionTombstone(tombstone: $0) }
            )
            defaults.set(tombstoneData, forKey: deletionStorageKey)
        } catch {
            assertionFailure("Failed to save memory state: \(error)")
        }
    }

    private func loadDeletionTombstones() {
        guard let data = defaults.data(forKey: deletionStorageKey) else {
            deletionTombstones = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let storedTombstones = try decoder.decode([StoredMemoryDeletionTombstone].self, from: data)
            deletionTombstones = storedTombstones
                .map(\.model)
                .sorted { $0.deletedAt > $1.deletedAt }
        } catch {
            deletionTombstones = []
        }
    }

    private func upsertDeletionTombstone(_ tombstone: MemoryDeletionTombstone, in scope: AppContentScope) {
        let preparedTombstone = tombstone.preparedForScopeReplacement(in: scope)
        if let index = deletionTombstones.firstIndex(where: { $0.id == preparedTombstone.id && $0.matches(scope: scope) }) {
            if deletionTombstones[index].deletedAt >= preparedTombstone.deletedAt {
                return
            }
            deletionTombstones[index] = preparedTombstone
        } else {
            deletionTombstones.append(preparedTombstone)
        }
        deletionTombstones.sort { $0.deletedAt > $1.deletedAt }
    }
}

@MainActor
final class WishStore: ObservableObject {
    @Published private(set) var wishes: [PlaceWish] = []
    @Published private(set) var deletionTombstones: [WishDeletionTombstone] = []

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.placeWishes"
    private let deletionStorageKey = "com.barry.CoupleSpace.placeWishDeletionTombstones"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var hasPersistedWishes: Bool {
        !wishes.isEmpty || !deletionTombstones.isEmpty
    }

    func wishes(in scope: AppContentScope) -> [PlaceWish] {
        let deletedIDs = Set(deletionTombstones(in: scope).map(\.id))
        return wishes
            .filter { $0.matches(scope: scope) && deletedIDs.contains($0.id) == false }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.title < rhs.title
                }

                return lhs.status.sortOrder < rhs.status.sortOrder
            }
    }

    func deletionTombstones(in scope: AppContentScope) -> [WishDeletionTombstone] {
        deletionTombstones
            .filter { $0.matches(scope: scope) }
            .sorted { $0.deletedAt > $1.deletedAt }
    }

    func add(_ wish: PlaceWish, in scope: AppContentScope) {
        let preparedWish = wish.preparedForLocalInsert(in: scope)
        debugWishStore(
            "local add id=\(preparedWish.id.uuidString.lowercased()) user=\(preparedWish.createdByUserId) space=\(preparedWish.spaceId) updatedAt=\(preparedWish.updatedAt.timeIntervalSince1970)"
        )
        wishes.append(preparedWish)
        save()
    }

    func update(_ wish: PlaceWish, in scope: AppContentScope) {
        guard let index = wishes.firstIndex(where: { $0.id == wish.id && $0.matches(scope: scope) }) else {
            return
        }

        let updatedWish = wishes[index].preparedForContentUpdate(
            title: wish.title,
            detail: wish.detail,
            note: wish.note,
            category: wish.category,
            status: wish.status,
            targetText: wish.targetText,
            symbol: wish.symbol,
            scope: scope
        )
        debugWishStore(
            "local update id=\(updatedWish.id.uuidString.lowercased()) user=\(updatedWish.createdByUserId) space=\(updatedWish.spaceId) updatedAt=\(updatedWish.updatedAt.timeIntervalSince1970) category=\(updatedWish.category.rawValue) status=\(updatedWish.status.rawValue)"
        )
        wishes[index] = updatedWish
        save()
    }

    func delete(_ wishID: UUID, in scope: AppContentScope) {
        guard wishes.contains(where: { $0.id == wishID && $0.matches(scope: scope) }) else {
            return
        }
        debugWishStore(
            "local delete id=\(wishID.uuidString.lowercased()) space=\(scope.spaceId) user=\(scope.currentUserId)"
        )
        wishes.removeAll { $0.id == wishID && $0.matches(scope: scope) }
        upsertDeletionTombstone(
            WishDeletionTombstone(
                id: wishID,
                spaceId: scope.spaceId,
                deletedByUserId: scope.currentUserId
            ),
            in: scope
        )
        save()
    }

    func replaceWishes(in scope: AppContentScope, with importedWishes: [PlaceWish]) {
        wishes.removeAll { $0.matches(scope: scope) }
        deletionTombstones.removeAll { $0.matches(scope: scope) }
        wishes.append(contentsOf: importedWishes.map { $0.preparedForScopeReplacement(in: scope) })
        save()
    }

    func mergeRemoteWishes(in scope: AppContentScope, with importedWishes: [PlaceWish]) {
        let deletedIDs = Set(deletionTombstones(in: scope).map(\.id))
        let localScopedWishes = wishes.filter { $0.matches(scope: scope) }
        let localBeforeByID = Dictionary(uniqueKeysWithValues: localScopedWishes.map { ($0.id, $0) })
        var mergedByID = Dictionary(
            uniqueKeysWithValues: localScopedWishes
                .filter { deletedIDs.contains($0.id) == false }
                .map { ($0.id, $0) }
        )

        debugWishStore(
            "merge remote begin space=\(scope.spaceId) localBefore=\(wishDebugSummary(localScopedWishes)) imported=\(wishDebugSummary(importedWishes)) deleted=\(deletedIDs.map { $0.uuidString.lowercased() }.sorted().joined(separator: ","))"
        )

        for importedWish in importedWishes {
            guard deletedIDs.contains(importedWish.id) == false else { continue }

            let preparedWish = importedWish.preparedForScopeReplacement(in: scope)
            if let existingWish = mergedByID[preparedWish.id] {
                let mergedWish = existingWish.mergedForSync(with: preparedWish, scope: scope)
                debugWishStore(
                    "merge remote resolve id=\(preparedWish.id.uuidString.lowercased()) localUpdatedAt=\(existingWish.updatedAt.timeIntervalSince1970) remoteUpdatedAt=\(preparedWish.updatedAt.timeIntervalSince1970) finalUpdatedAt=\(mergedWish.updatedAt.timeIntervalSince1970) finalCategory=\(mergedWish.category.rawValue) finalStatus=\(mergedWish.status.rawValue)"
                )
                mergedByID[preparedWish.id] = mergedWish
                continue
            }
            if let existingWish = localBeforeByID[preparedWish.id] {
                debugWishStore(
                    "merge remote upsert id=\(preparedWish.id.uuidString.lowercased()) localUpdatedAt=\(existingWish.updatedAt.timeIntervalSince1970) remoteUpdatedAt=\(preparedWish.updatedAt.timeIntervalSince1970) category=\(preparedWish.category.rawValue)"
                )
            } else {
                debugWishStore(
                    "merge remote insert id=\(preparedWish.id.uuidString.lowercased()) remoteUpdatedAt=\(preparedWish.updatedAt.timeIntervalSince1970) category=\(preparedWish.category.rawValue)"
                )
            }
            mergedByID[preparedWish.id] = preparedWish
        }

        wishes.removeAll { $0.matches(scope: scope) }
        wishes.append(contentsOf: mergedByID.values)
        debugWishStore(
            "merge remote end space=\(scope.spaceId) localAfter=\(wishDebugSummary(wishes.filter { $0.matches(scope: scope) }))"
        )
        save()
    }

    @discardableResult
    func mergeDeletionTombstones(
        in scope: AppContentScope,
        with importedTombstones: [WishDeletionTombstone]
    ) -> [WishDeletionTombstone] {
        let keptTombstones = deletionTombstones.filter { !$0.matches(scope: scope) }
        var mergedByID = Dictionary(
            uniqueKeysWithValues: deletionTombstones(in: scope).map { ($0.id, $0) }
        )

        for tombstone in importedTombstones {
            guard tombstone.matches(scope: scope) else { continue }
            if let existing = mergedByID[tombstone.id], existing.deletedAt >= tombstone.deletedAt {
                continue
            }
            mergedByID[tombstone.id] = tombstone.preparedForScopeReplacement(in: scope)
        }

        let mergedTombstones = mergedByID.values.sorted { $0.deletedAt > $1.deletedAt }
        deletionTombstones = keptTombstones + mergedTombstones

        let deletedIDs = Set(mergedTombstones.map(\.id))
        debugWishStore(
            "merge tombstones space=\(scope.spaceId) merged=\(wishTombstoneDebugSummary(mergedTombstones))"
        )
        wishes.removeAll { $0.matches(scope: scope) && deletedIDs.contains($0.id) }
        save()
        return mergedTombstones
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            wishes = []
            return
        }

        do {
            let decoder = makeWishStoreJSONDecoder()
            let decoded = try decoder.decode([StoredWish].self, from: data)
            wishes = decoded.map(\.model)
        } catch {
            wishes = []
        }
        loadDeletionTombstones()
    }

    private func save() {
        do {
            let encoder = makeWishStoreJSONEncoder()
            let data = try encoder.encode(wishes.map { StoredWish(wish: $0) })
            defaults.set(data, forKey: storageKey)
            let tombstoneData = try encoder.encode(
                deletionTombstones.map { StoredWishDeletionTombstone(tombstone: $0) }
            )
            defaults.set(tombstoneData, forKey: deletionStorageKey)
        } catch {
            assertionFailure("Failed to save wishes: \(error)")
        }
    }

    private func loadDeletionTombstones() {
        guard let data = defaults.data(forKey: deletionStorageKey) else {
            deletionTombstones = []
            return
        }

        do {
            let decoder = makeWishStoreJSONDecoder()
            let decoded = try decoder.decode([StoredWishDeletionTombstone].self, from: data)
            deletionTombstones = decoded
                .map(\.model)
                .sorted { $0.deletedAt > $1.deletedAt }
        } catch {
            deletionTombstones = []
        }
    }

    private func upsertDeletionTombstone(_ tombstone: WishDeletionTombstone, in scope: AppContentScope) {
        let preparedTombstone = tombstone.preparedForScopeReplacement(in: scope)
        if let index = deletionTombstones.firstIndex(where: { $0.id == preparedTombstone.id && $0.matches(scope: scope) }) {
            if deletionTombstones[index].deletedAt >= preparedTombstone.deletedAt {
                return
            }
            deletionTombstones[index] = preparedTombstone
        } else {
            deletionTombstones.append(preparedTombstone)
        }
        deletionTombstones.sort { $0.deletedAt > $1.deletedAt }
    }

    private func wishDebugSummary(_ wishes: [PlaceWish]) -> String {
        if wishes.isEmpty {
            return "[]"
        }

        let summary = wishes
            .sorted { $0.updatedAt < $1.updatedAt }
            .map {
                String(
                    format: "%@|user=%@|updatedAt=%.6f|category=%@|status=%@",
                    $0.id.uuidString.lowercased(),
                    $0.createdByUserId,
                    $0.updatedAt.timeIntervalSince1970,
                    $0.category.rawValue,
                    $0.status.rawValue
                )
            }
            .joined(separator: ",")
        return "[\(summary)]"
    }

    private func wishTombstoneDebugSummary(_ tombstones: [WishDeletionTombstone]) -> String {
        if tombstones.isEmpty {
            return "[]"
        }

        let summary = tombstones
            .sorted { $0.deletedAt < $1.deletedAt }
            .map {
                String(
                    format: "%@|deletedBy=%@|deletedAt=%.6f",
                    $0.id.uuidString.lowercased(),
                    $0.deletedByUserId,
                    $0.deletedAt.timeIntervalSince1970
                )
            }
            .joined(separator: ",")
        return "[\(summary)]"
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

    func mergeRemoteItems(in scope: AppContentScope, with importedItems: [WeeklyTodoItem]) {
        let localScopedItems = items.filter { $0.matches(scope: scope) }
        var mergedByID = Dictionary(
            uniqueKeysWithValues: localScopedItems.map { ($0.id, $0) }
        )

        for importedItem in importedItems {
            let preparedItem = importedItem.preparedForScopeReplacement(in: scope)
            if let existingItem = mergedByID[preparedItem.id],
               existingItem.updatedAt > preparedItem.updatedAt {
                continue
            }
            mergedByID[preparedItem.id] = preparedItem
        }

        items.removeAll { $0.matches(scope: scope) }
        items.append(contentsOf: mergedByID.values)
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
            .sorted(by: Self.compareItems(_:_:))
    }

    func add(_ item: TonightDinnerOption, in scope: AppContentScope) {
        items.append(item.preparedForLocalInsert(in: scope))
        items.sort(by: Self.compareItems(_:_:))
        save()
    }

    func choose(_ itemID: UUID, in scope: AppContentScope) {
        var didMutate = false
        let calendar = Calendar.current
        let now = Date()

        items = items.map { item in
            guard item.matches(scope: scope) else { return item }

            if item.id == itemID {
                didMutate = true
                return item.preparedForSelectionMutation(status: .chosen, scope: scope)
            }

            if item.status == .chosen,
               let decidedAt = item.decidedAt,
               calendar.isDate(decidedAt, inSameDayAs: now) {
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
            .map { $0.normalizedForCurrentDay() }
            .sorted(by: Self.compareItems(_:_:))
    }

    func refreshCompletionStatesIfNeeded(
        in scope: AppContentScope,
        referenceDate: Date = .now
    ) {
        var didMutate = false

        items = items.map { item in
            guard item.matches(scope: scope) else { return item }
            guard item.needsCompletionReset(referenceDate: referenceDate) else { return item }

            didMutate = true
            return item.normalizedForCurrentDay(referenceDate: referenceDate)
        }

        guard didMutate else { return }
        items.sort(by: Self.compareItems(_:_:))
        save()
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
    let remoteAssetID: String?
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
        remoteAssetID = entry.remoteAssetID
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
            remoteAssetID: remoteAssetID,
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

private struct StoredMemoryDeletionTombstone: Codable {
    let id: UUID
    let spaceId: String
    let deletedByUserId: String
    let deletedAt: Date

    init(tombstone: MemoryDeletionTombstone) {
        id = tombstone.id
        spaceId = tombstone.spaceId
        deletedByUserId = tombstone.deletedByUserId
        deletedAt = tombstone.deletedAt
    }

    var model: MemoryDeletionTombstone {
        MemoryDeletionTombstone(
            id: id,
            spaceId: spaceId,
            deletedByUserId: deletedByUserId,
            deletedAt: deletedAt
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
    private static let uploadTargetMaxBytes = 850_000
    private static let uploadCompressionQualities: [CGFloat] = [0.82, 0.72, 0.62, 0.52, 0.42, 0.32]
    private static let uploadMaxPixelLengths: [CGFloat] = [1600, 1280, 1080, 960, 820]

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

    static func uploadImageData(for filename: String?, maxBytes: Int = uploadTargetMaxBytes) -> Data? {
        guard let originalData = imageData(for: filename) else { return nil }
        if originalData.count <= maxBytes {
            return originalData
        }

        guard let image = uiImage(for: filename) else { return originalData }

        for pixelLength in uploadMaxPixelLengths {
            let resizedImage = resizedImageIfNeeded(image, maxPixelLength: pixelLength)
            for quality in uploadCompressionQualities {
                guard let candidateData = resizedImage.jpegData(compressionQuality: quality) else { continue }
                if candidateData.count <= maxBytes {
                    return candidateData
                }
            }
        }

        return resizedImageIfNeeded(image, maxPixelLength: uploadMaxPixelLengths.last ?? 820)
            .jpegData(compressionQuality: uploadCompressionQualities.last ?? 0.32)
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

    private static func resizedImageIfNeeded(_ image: UIImage, maxPixelLength: CGFloat) -> UIImage {
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxPixelLength, largestSide > 0 else { return image }

        let scale = maxPixelLength / largestSide
        let targetSize = CGSize(
            width: max(image.size.width * scale, 1),
            height: max(image.size.height * scale, 1)
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private struct StoredWish: Codable {
    let id: UUID
    let title: String
    let titleUpdatedAt: Date?
    let detail: String
    let detailUpdatedAt: Date?
    let note: String
    let noteUpdatedAt: Date?
    let categoryRawValue: String
    let categoryUpdatedAt: Date?
    let statusRawValue: String
    let statusUpdatedAt: Date?
    let targetText: String
    let targetTextUpdatedAt: Date?
    let symbol: String
    let spaceId: String?
    let createdByUserId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let updatedAtTimestamp: TimeInterval?
    let syncStatusRawValue: String?

    init(wish: PlaceWish) {
        id = wish.id
        title = wish.title
        titleUpdatedAt = wish.titleUpdatedAt
        detail = wish.detail
        detailUpdatedAt = wish.detailUpdatedAt
        note = wish.note
        noteUpdatedAt = wish.noteUpdatedAt
        categoryRawValue = wish.category.rawValue
        categoryUpdatedAt = wish.categoryUpdatedAt
        statusRawValue = wish.status.rawValue
        statusUpdatedAt = wish.statusUpdatedAt
        targetText = wish.targetText
        targetTextUpdatedAt = wish.targetTextUpdatedAt
        symbol = wish.symbol
        spaceId = wish.spaceId
        createdByUserId = wish.createdByUserId
        createdAt = wish.createdAt
        updatedAt = wish.updatedAt
        updatedAtTimestamp = wish.updatedAt.timeIntervalSince1970
        syncStatusRawValue = wish.syncStatus.rawValue
    }

    var model: PlaceWish {
        let resolvedCreatedAt = createdAt ?? .now
        let resolvedUpdatedAt = updatedAtTimestamp.map(Date.init(timeIntervalSince1970:))
            ?? updatedAt
            ?? resolvedCreatedAt
        return PlaceWish(
            id: id,
            title: title,
            titleUpdatedAt: titleUpdatedAt,
            detail: detail,
            detailUpdatedAt: detailUpdatedAt,
            note: note,
            noteUpdatedAt: noteUpdatedAt,
            category: WishCategory(rawValue: categoryRawValue) ?? .date,
            categoryUpdatedAt: categoryUpdatedAt,
            status: WishStatus(rawValue: statusRawValue) ?? .dreaming,
            statusUpdatedAt: statusUpdatedAt,
            targetText: targetText,
            targetTextUpdatedAt: targetTextUpdatedAt,
            symbol: symbol,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            createdByUserId: createdByUserId ?? AppDataDefaults.localUserId,
            createdAt: resolvedCreatedAt,
            updatedAt: resolvedUpdatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}

private struct StoredWishDeletionTombstone: Codable {
    let id: UUID
    let spaceId: String?
    let deletedByUserId: String?
    let deletedAt: Date?

    init(tombstone: WishDeletionTombstone) {
        id = tombstone.id
        spaceId = tombstone.spaceId
        deletedByUserId = tombstone.deletedByUserId
        deletedAt = tombstone.deletedAt
    }

    var model: WishDeletionTombstone {
        WishDeletionTombstone(
            id: id,
            spaceId: spaceId ?? AppDataDefaults.localSpaceId,
            deletedByUserId: deletedByUserId ?? AppDataDefaults.localUserId,
            deletedAt: deletedAt ?? .now
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
    let completedAt: Date?
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
        completedAt = item.completedAt
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
            completedAt: completedAt ?? (isCompleted ? (updatedAt ?? resolvedCreatedAt) : nil),
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
            remoteAssetID: remoteAssetID,
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
            remoteAssetID: remoteAssetID,
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

    func preparedForScopeReplacement(
        in scope: AppContentScope,
        preservingLocalImageMetadataFrom existingEntry: MemoryTimelineEntry? = nil
    ) -> MemoryTimelineEntry {
        let resolvedPhotoFilename = photoFilename ?? existingEntry?.photoFilename
        let resolvedRemoteAssetID = remoteAssetID ?? existingEntry?.remoteAssetID
        return MemoryTimelineEntry(
            id: id,
            title: title,
            detail: detail,
            date: date,
            category: category,
            imageLabel: imageLabel,
            photoFilename: resolvedPhotoFilename,
            remoteAssetID: resolvedRemoteAssetID,
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
            remoteAssetID: photoFilename == self.photoFilename ? remoteAssetID : nil,
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

private extension MemoryDeletionTombstone {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId || (scope.isSharedSpace && spaceId == AppDataDefaults.localSpaceId)
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> MemoryDeletionTombstone {
        MemoryDeletionTombstone(
            id: id,
            spaceId: scope.spaceId,
            deletedByUserId: deletedByUserId,
            deletedAt: deletedAt
        )
    }
}

private extension PlaceWish {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId
    }

    func preparedForLocalInsert(in scope: AppContentScope) -> PlaceWish {
        let mutationAt = Date.now
        return PlaceWish(
            id: id,
            title: title,
            titleUpdatedAt: mutationAt,
            detail: detail,
            detailUpdatedAt: mutationAt,
            note: note,
            noteUpdatedAt: mutationAt,
            category: category,
            categoryUpdatedAt: mutationAt,
            status: status,
            statusUpdatedAt: mutationAt,
            targetText: targetText,
            targetTextUpdatedAt: mutationAt,
            symbol: symbol,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: createdAt,
            updatedAt: mutationAt,
            syncStatus: .localOnly
        )
    }

    func scopedToSeed(_ scope: AppContentScope) -> PlaceWish {
        return PlaceWish(
            id: id,
            title: title,
            titleUpdatedAt: titleUpdatedAt,
            detail: detail,
            detailUpdatedAt: detailUpdatedAt,
            note: note,
            noteUpdatedAt: noteUpdatedAt,
            category: category,
            categoryUpdatedAt: categoryUpdatedAt,
            status: status,
            statusUpdatedAt: statusUpdatedAt,
            targetText: targetText,
            targetTextUpdatedAt: targetTextUpdatedAt,
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
            titleUpdatedAt: titleUpdatedAt,
            detail: detail,
            detailUpdatedAt: detailUpdatedAt,
            note: note,
            noteUpdatedAt: noteUpdatedAt,
            category: category,
            categoryUpdatedAt: categoryUpdatedAt,
            status: status,
            statusUpdatedAt: statusUpdatedAt,
            targetText: targetText,
            targetTextUpdatedAt: targetTextUpdatedAt,
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
        let mutationAt = Date.now
        let resolvedTitleUpdatedAt = title == self.title ? titleUpdatedAt : mutationAt
        let resolvedDetailUpdatedAt = detail == self.detail ? detailUpdatedAt : mutationAt
        let resolvedNoteUpdatedAt = note == self.note ? noteUpdatedAt : mutationAt
        let resolvedCategoryUpdatedAt = (category == self.category && symbol == self.symbol)
            ? categoryUpdatedAt
            : mutationAt
        let resolvedStatusUpdatedAt = status == self.status ? statusUpdatedAt : mutationAt
        let resolvedTargetTextUpdatedAt = targetText == self.targetText ? targetTextUpdatedAt : mutationAt
        return PlaceWish(
            id: id,
            title: title,
            titleUpdatedAt: resolvedTitleUpdatedAt,
            detail: detail,
            detailUpdatedAt: resolvedDetailUpdatedAt,
            note: note,
            noteUpdatedAt: resolvedNoteUpdatedAt,
            category: category,
            categoryUpdatedAt: resolvedCategoryUpdatedAt,
            status: status,
            statusUpdatedAt: resolvedStatusUpdatedAt,
            targetText: targetText,
            targetTextUpdatedAt: resolvedTargetTextUpdatedAt,
            symbol: symbol,
            spaceId: scope.spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: [
                mutationAt,
                resolvedTitleUpdatedAt,
                resolvedDetailUpdatedAt,
                resolvedNoteUpdatedAt,
                resolvedCategoryUpdatedAt,
                resolvedStatusUpdatedAt,
                resolvedTargetTextUpdatedAt
            ].max(),
            syncStatus: .localOnly
        )
    }

    func mergedForSync(with remoteWish: PlaceWish, scope: AppContentScope) -> PlaceWish {
        let resolvedRemoteWish = remoteWish.preparedForScopeReplacement(in: scope)
        let resolvedTitle = resolveWishField(
            localValue: title,
            localUpdatedAt: titleUpdatedAt,
            remoteValue: resolvedRemoteWish.title,
            remoteUpdatedAt: wishFieldResolutionTime(resolvedRemoteWish.titleUpdatedAt, fallback: resolvedRemoteWish),
            localWish: self,
            remoteWish: resolvedRemoteWish
        )
        let resolvedDetail = resolveWishField(
            localValue: detail,
            localUpdatedAt: detailUpdatedAt,
            remoteValue: resolvedRemoteWish.detail,
            remoteUpdatedAt: wishFieldResolutionTime(resolvedRemoteWish.detailUpdatedAt, fallback: resolvedRemoteWish),
            localWish: self,
            remoteWish: resolvedRemoteWish
        )
        let resolvedNote = resolveWishField(
            localValue: note,
            localUpdatedAt: noteUpdatedAt,
            remoteValue: resolvedRemoteWish.note,
            remoteUpdatedAt: wishFieldResolutionTime(resolvedRemoteWish.noteUpdatedAt, fallback: resolvedRemoteWish),
            localWish: self,
            remoteWish: resolvedRemoteWish
        )
        let resolvedCategory = resolveWishField(
            localValue: (category, symbol),
            localUpdatedAt: categoryUpdatedAt,
            remoteValue: (resolvedRemoteWish.category, resolvedRemoteWish.symbol),
            remoteUpdatedAt: wishFieldResolutionTime(resolvedRemoteWish.categoryUpdatedAt, fallback: resolvedRemoteWish),
            localWish: self,
            remoteWish: resolvedRemoteWish
        )
        let resolvedStatus = resolveWishField(
            localValue: status,
            localUpdatedAt: statusUpdatedAt,
            remoteValue: resolvedRemoteWish.status,
            remoteUpdatedAt: wishFieldResolutionTime(resolvedRemoteWish.statusUpdatedAt, fallback: resolvedRemoteWish),
            localWish: self,
            remoteWish: resolvedRemoteWish
        )
        let resolvedTargetText = resolveWishField(
            localValue: targetText,
            localUpdatedAt: targetTextUpdatedAt,
            remoteValue: resolvedRemoteWish.targetText,
            remoteUpdatedAt: wishFieldResolutionTime(resolvedRemoteWish.targetTextUpdatedAt, fallback: resolvedRemoteWish),
            localWish: self,
            remoteWish: resolvedRemoteWish
        )
        let preferredWish = resolvedRemoteWish.updatedAt > updatedAt ? resolvedRemoteWish : self
        return PlaceWish(
            id: id,
            title: resolvedTitle.0,
            titleUpdatedAt: resolvedTitle.1,
            detail: resolvedDetail.0,
            detailUpdatedAt: resolvedDetail.1,
            note: resolvedNote.0,
            noteUpdatedAt: resolvedNote.1,
            category: resolvedCategory.0.0,
            categoryUpdatedAt: resolvedCategory.1,
            status: resolvedStatus.0,
            statusUpdatedAt: resolvedStatus.1,
            targetText: resolvedTargetText.0,
            targetTextUpdatedAt: resolvedTargetText.1,
            symbol: resolvedCategory.0.1,
            spaceId: scope.spaceId,
            createdByUserId: preferredWish.createdByUserId,
            createdAt: min(createdAt, resolvedRemoteWish.createdAt),
            updatedAt: [
                preferredWish.updatedAt,
                resolvedTitle.1,
                resolvedDetail.1,
                resolvedNote.1,
                resolvedCategory.1,
                resolvedStatus.1,
                resolvedTargetText.1
            ].max(),
            syncStatus: preferredWish.syncStatus
        )
    }
}

private extension WishDeletionTombstone {
    func matches(scope: AppContentScope) -> Bool {
        spaceId == scope.spaceId
    }

    func preparedForScopeReplacement(in scope: AppContentScope) -> WishDeletionTombstone {
        WishDeletionTombstone(
            id: id,
            spaceId: scope.spaceId,
            deletedByUserId: deletedByUserId,
            deletedAt: deletedAt
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
            completedAt: nil,
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
            completedAt: isCompleted ? .now : nil,
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
            completedAt: completedAt,
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
            completedAt: completedAt,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdByUserId: createdByUserId,
            spaceId: scope.spaceId,
            syncStatus: syncStatus
        )
    }

    func needsCompletionReset(referenceDate: Date = .now) -> Bool {
        guard isCompleted else { return false }
        guard let completedAt else { return true }
        return !Calendar.current.isDate(completedAt, inSameDayAs: referenceDate)
    }

    func normalizedForCurrentDay(referenceDate: Date = .now) -> RitualItem {
        guard needsCompletionReset(referenceDate: referenceDate) else { return self }

        return RitualItem(
            id: id,
            title: title,
            kind: kind,
            isCompleted: false,
            completedAt: nil,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: syncStatus
        )
    }
}

private extension TonightDinnerOption {
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
