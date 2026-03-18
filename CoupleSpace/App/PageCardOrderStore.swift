import Foundation

enum HomeSortableCardID: String, CaseIterable, Identifiable, Hashable {
    case anniversary
    case wish
    case recentMemory
    case whisper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anniversary:
            return "纪念日预览"
        case .wish:
            return "愿望清单预览"
        case .recentMemory:
            return "最近记录预览"
        case .whisper:
            return "悄悄话预览"
        }
    }

    var subtitle: String {
        switch self {
        case .anniversary:
            return "首页里最靠近时间感的一张卡。"
        case .wish:
            return "最近想推进的一件共同期待。"
        case .recentMemory:
            return "最近留下来的生活记录。"
        case .whisper:
            return "留给对方、不一定当面说出口的小纸条。"
        }
    }

    var symbol: String {
        switch self {
        case .anniversary:
            return "calendar.badge.clock"
        case .wish:
            return "paperplane.fill"
        case .recentMemory:
            return "heart.text.square"
        case .whisper:
            return "envelope.badge"
        }
    }

    static let defaultOrder: [HomeSortableCardID] = [.anniversary, .wish, .recentMemory, .whisper]
}

enum LifeSortableCardID: String, CaseIterable, Identifiable, Hashable {
    case weeklyTodo
    case dinner
    case placeWish
    case ritual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weeklyTodo:
            return "本周事项"
        case .dinner:
            return "今晚吃什么"
        case .placeWish:
            return "愿望清单"
        case .ritual:
            return "小约定"
        }
    }

    var subtitle: String {
        switch self {
        case .weeklyTodo:
            return "这周要一起记得的事。"
        case .dinner:
            return "轻松决定今天吃什么。"
        case .placeWish:
            return "慢慢累积的共同期待。"
        case .ritual:
            return "慢慢养成的日常默契。"
        }
    }

    var symbol: String {
        switch self {
        case .weeklyTodo:
            return "checklist"
        case .dinner:
            return "fork.knife"
        case .placeWish:
            return "paperplane.fill"
        case .ritual:
            return "heart"
        }
    }

    static let defaultOrder: [LifeSortableCardID] = [.weeklyTodo, .dinner, .placeWish, .ritual]
}

@MainActor
final class PageCardOrderStore: ObservableObject {
    @Published private(set) var homeOrder: [HomeSortableCardID]
    @Published private(set) var lifeOrder: [LifeSortableCardID]

    private let defaults: UserDefaults
    private let homeKey = "com.barry.CoupleSpace.pageCardOrder.home"
    private let lifeKey = "com.barry.CoupleSpace.pageCardOrder.life"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        homeOrder = Self.loadOrder(
            forKey: homeKey,
            defaults: defaults,
            defaultOrder: HomeSortableCardID.defaultOrder
        )
        lifeOrder = Self.loadOrder(
            forKey: lifeKey,
            defaults: defaults,
            defaultOrder: LifeSortableCardID.defaultOrder
        )
    }

    func setHomeOrder(_ newValue: [HomeSortableCardID]) {
        homeOrder = Self.normalizedOrder(newValue, defaultOrder: HomeSortableCardID.defaultOrder)
        saveHomeOrder()
    }

    func setLifeOrder(_ newValue: [LifeSortableCardID]) {
        lifeOrder = Self.normalizedOrder(newValue, defaultOrder: LifeSortableCardID.defaultOrder)
        saveLifeOrder()
    }

    func resetHomeOrder() {
        homeOrder = HomeSortableCardID.defaultOrder
        saveHomeOrder()
    }

    func resetLifeOrder() {
        lifeOrder = LifeSortableCardID.defaultOrder
        saveLifeOrder()
    }

    private func saveHomeOrder() {
        defaults.set(homeOrder.map(\.rawValue), forKey: homeKey)
    }

    private func saveLifeOrder() {
        defaults.set(lifeOrder.map(\.rawValue), forKey: lifeKey)
    }

    private static func loadOrder<Item: RawRepresentable & CaseIterable & Hashable>(
        forKey key: String,
        defaults: UserDefaults,
        defaultOrder: [Item]
    ) -> [Item] where Item.RawValue == String {
        let storedRawValues = defaults.stringArray(forKey: key) ?? []
        let restored = storedRawValues.compactMap(Item.init(rawValue:))
        return normalizedOrder(restored, defaultOrder: defaultOrder)
    }

    private static func normalizedOrder<Item: CaseIterable & Hashable>(
        _ items: [Item],
        defaultOrder: [Item]
    ) -> [Item] {
        var seen = Set<Item>()
        var normalized: [Item] = []

        for item in items where !seen.contains(item) {
            normalized.append(item)
            seen.insert(item)
        }

        for item in defaultOrder where !seen.contains(item) {
            normalized.append(item)
            seen.insert(item)
        }

        for item in Item.allCases where !seen.contains(item) {
            normalized.append(item)
            seen.insert(item)
        }

        return normalized
    }
}
