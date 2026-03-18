import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
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
}
