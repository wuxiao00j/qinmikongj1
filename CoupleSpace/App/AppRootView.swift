import Combine
import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let automaticPullHeartbeat = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    @StateObject private var navigationState = AppNavigationState()
    @StateObject private var memoryStore = MemoryStore()
    @StateObject private var wishStore = WishStore()
    @StateObject private var anniversaryStore = AnniversaryStore()
    @StateObject private var weeklyTodoStore = WeeklyTodoStore()
    @StateObject private var tonightDinnerStore = TonightDinnerStore()
    @StateObject private var ritualStore = RitualStore()
    @StateObject private var currentStatusStore = CurrentStatusStore()
    @StateObject private var whisperNoteStore = WhisperNoteStore()
    @StateObject private var pageCardOrderStore = PageCardOrderStore()
    @StateObject private var relationshipStore: RelationshipStore
    @StateObject private var accountSessionStore: AccountSessionStore
    @StateObject private var syncService: AppSyncService

    init() {
        let accountSessionStore = AccountSessionStore()
        let relationshipStore = RelationshipStore(accountSessionStore: accountSessionStore)
        let providerConfiguration = AppSyncProviderConfiguration.current
        // 当前 provider 选择统一收在配置入口里。
        // fake 仍然是默认；未来开始接真实 API 时，优先只把这里切到 RealSyncRemoteProvider。
        let remoteProvider = providerConfiguration.makeRemoteProvider(
            accountSessionStore: accountSessionStore
        )

        _relationshipStore = StateObject(wrappedValue: relationshipStore)
        _accountSessionStore = StateObject(wrappedValue: accountSessionStore)
        _syncService = StateObject(
            wrappedValue: AppSyncService(
                sessionStore: accountSessionStore,
                relationshipStore: relationshipStore,
                remoteProvider: remoteProvider
            )
        )
    }

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(AppTab.home)

            LifeView()
                .tabItem {
                    Label("生活", systemImage: "leaf")
                }
                .tag(AppTab.life)

            MemoryView()
                .tabItem {
                    Label("记忆", systemImage: "heart.text.square")
                }
                .tag(AppTab.memory)

            MeView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(AppTab.me)
        }
        .tint(AppTheme.Colors.tint)
        .onAppear(perform: refreshWidgetSnapshots)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshWidgetSnapshots()
            Task {
                await relationshipStore.refreshRemoteRelationshipStatusIfNeeded()
                let resumedPendingPush = syncService.resumePendingAutomaticPushIfPossible(
                    memories: memoryStore.entries(in: relationshipStore.contentScope),
                    memoryTombstones: memoryStore.deletionTombstones(in: relationshipStore.contentScope),
                    wishes: wishStore.wishes(in: relationshipStore.contentScope),
                    wishTombstones: wishStore.deletionTombstones(in: relationshipStore.contentScope),
                    anniversaries: anniversaryStore.anniversaries(in: relationshipStore.contentScope),
                    weeklyTodos: weeklyTodoStore.items(in: relationshipStore.contentScope),
                    tonightDinners: tonightDinnerStore.items(in: relationshipStore.contentScope),
                    rituals: ritualStore.items(in: relationshipStore.contentScope),
                    currentStatuses: currentStatusStore.items(in: relationshipStore.contentScope),
                    whisperNotes: whisperNoteStore.items(in: relationshipStore.contentScope),
                    scope: relationshipStore.contentScope,
                    trigger: .appBecameActive
                )
                guard resumedPendingPush == false else { return }
                syncService.scheduleAutomaticPullIfPossible(
                    scope: relationshipStore.contentScope,
                    memoryStore: memoryStore,
                    wishStore: wishStore,
                    anniversaryStore: anniversaryStore,
                    weeklyTodoStore: weeklyTodoStore,
                    tonightDinnerStore: tonightDinnerStore,
                    ritualStore: ritualStore,
                    currentStatusStore: currentStatusStore,
                    whisperNoteStore: whisperNoteStore,
                    trigger: .appBecameActive
                )
            }
        }
        .onReceive(relationshipStore.$state) { _ in
            refreshWidgetSnapshots()
        }
        .onReceive(anniversaryStore.$anniversaries) { _ in
            refreshAnniversaryWidgetSnapshot()
        }
        .onReceive(memoryStore.$entries) { _ in
            refreshMemoryWidgetSnapshot()
        }
        .onReceive(memoryStore.$entries.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .memoriesChanged)
        }
        .onReceive(memoryStore.$deletionTombstones.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .memoriesChanged)
        }
        .onReceive(wishStore.$wishes.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .wishesChanged)
        }
        .onReceive(wishStore.$deletionTombstones.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .wishesChanged)
        }
        .onReceive(anniversaryStore.$anniversaries.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .anniversariesChanged)
        }
        .onReceive(weeklyTodoStore.$items.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .weeklyTodosChanged)
        }
        .onReceive(tonightDinnerStore.$items.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .tonightDinnersChanged)
        }
        .onReceive(ritualStore.$items.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .ritualsChanged)
        }
        .onReceive(currentStatusStore.$items.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .currentStatusesChanged)
        }
        .onReceive(whisperNoteStore.$items.dropFirst()) { _ in
            scheduleAutomaticPush(trigger: .whisperNotesChanged)
        }
        .onReceive(automaticPullHeartbeat) { _ in
            guard scenePhase == .active else { return }
            syncService.scheduleAutomaticPullIfPossible(
                scope: relationshipStore.contentScope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore,
                trigger: .foregroundHeartbeat
            )
        }
        .onChange(of: syncService.status.lastPushAt) { oldValue, newValue in
            guard let newValue, newValue != oldValue else { return }
            syncService.schedulePostPushConvergencePullIfPossible(
                scope: relationshipStore.contentScope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore
            )
        }
        .onOpenURL { url in
            navigationState.handleOpenURL(url)
        }
        .environmentObject(navigationState)
        .environmentObject(memoryStore)
        .environmentObject(wishStore)
        .environmentObject(anniversaryStore)
        .environmentObject(weeklyTodoStore)
        .environmentObject(tonightDinnerStore)
        .environmentObject(ritualStore)
        .environmentObject(currentStatusStore)
        .environmentObject(whisperNoteStore)
        .environmentObject(pageCardOrderStore)
        .environmentObject(relationshipStore)
        .environmentObject(accountSessionStore)
        .environmentObject(syncService)
    }

    private func refreshAnniversaryWidgetSnapshot() {
        WidgetSnapshotBridge.refreshAnniversarySnapshot(
            relationship: relationshipStore.state,
            anniversaries: anniversaryStore.anniversaries
        )
    }

    private func refreshMemoryWidgetSnapshot() {
        WidgetSnapshotBridge.refreshMemorySnapshot(
            relationship: relationshipStore.state,
            entries: memoryStore.entries
        )
    }

    private func refreshWidgetSnapshots() {
        WidgetSnapshotBridge.refreshAllSnapshots(
            relationship: relationshipStore.state,
            anniversaries: anniversaryStore.anniversaries,
            entries: memoryStore.entries
        )
    }

    private func scheduleAutomaticPush(trigger: AutomaticSyncTrigger) {
        let scope = relationshipStore.contentScope
        syncService.scheduleAutomaticPushIfPossible(
            memories: memoryStore.entries(in: scope),
            memoryTombstones: memoryStore.deletionTombstones(in: scope),
            wishes: wishStore.wishes(in: scope),
            wishTombstones: wishStore.deletionTombstones(in: scope),
            anniversaries: anniversaryStore.anniversaries(in: scope),
            weeklyTodos: weeklyTodoStore.items(in: scope),
            tonightDinners: tonightDinnerStore.items(in: scope),
            rituals: ritualStore.items(in: scope),
            currentStatuses: currentStatusStore.items(in: scope),
            whisperNotes: whisperNoteStore.items(in: scope),
            scope: scope,
            trigger: trigger
        )
    }
}
