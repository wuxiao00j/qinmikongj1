import Foundation

enum WidgetSharedConfiguration {
    static let appGroupIdentifier = "group.com.barry.CoupleSpace"
}

enum WidgetSharedDefaults {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: WidgetSharedConfiguration.appGroupIdentifier) ?? .standard
    }
}

enum AppWidgetKind {
    static let anniversary = "CoupleSpaceAnniversaryWidget"
    static let memory = "CoupleSpaceMemoryWidget"
}

enum AppWidgetRoute {
    static let anniversaryPath = "anniversaries"
    static let anniversaryURL = URL(string: "couplespace://anniversaries")!
    static let memoryPath = "memories"
    static let memoryURL = URL(string: "couplespace://memories")!

    static func matchesAnniversary(_ url: URL) -> Bool {
        url.scheme == "couplespace" && url.host == anniversaryPath
    }

    static func matchesMemory(_ url: URL) -> Bool {
        url.scheme == "couplespace" && url.host == memoryPath
    }
}

enum WidgetAnniversaryCadence: String, Codable {
    case once
    case yearly
}

struct WidgetAnniversaryItemSnapshot: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let cadence: WidgetAnniversaryCadence
    let note: String
    let shortDateText: String
}

struct WidgetAnniversarySnapshot: Codable {
    let generatedAt: Date
    let spaceTitle: String
    let relationshipLabel: String
    let anniversaryCount: Int
    let nextAnniversary: WidgetAnniversaryItemSnapshot?
}

enum WidgetAnniversarySnapshotStore {
    private static let storageKey = "com.barry.CoupleSpace.widget.anniversarySnapshot"

    static func load() -> WidgetAnniversarySnapshot? {
        guard let data = WidgetSharedDefaults.defaults.data(forKey: storageKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetAnniversarySnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ snapshot: WidgetAnniversarySnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            WidgetSharedDefaults.defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save widget anniversary snapshot: \(error)")
        }
    }
}

struct WidgetMemoryItemSnapshot: Codable, Identifiable {
    let id: UUID
    let title: String
    let excerpt: String
    let date: Date
    let shortDateText: String
    let contextText: String
}

struct WidgetMemorySnapshot: Codable {
    let generatedAt: Date
    let spaceTitle: String
    let entryCount: Int
    let latestEntry: WidgetMemoryItemSnapshot?
}

enum WidgetMemorySnapshotStore {
    private static let storageKey = "com.barry.CoupleSpace.widget.memorySnapshot"

    static func load() -> WidgetMemorySnapshot? {
        guard let data = WidgetSharedDefaults.defaults.data(forKey: storageKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetMemorySnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ snapshot: WidgetMemorySnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            WidgetSharedDefaults.defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save widget memory snapshot: \(error)")
        }
    }
}
