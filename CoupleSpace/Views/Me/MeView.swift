import SwiftUI
import UIKit

struct MeView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @EnvironmentObject private var memoryStore: MemoryStore
    @EnvironmentObject private var wishStore: WishStore
    @EnvironmentObject private var anniversaryStore: AnniversaryStore
    @EnvironmentObject private var weeklyTodoStore: WeeklyTodoStore
    @EnvironmentObject private var tonightDinnerStore: TonightDinnerStore
    @EnvironmentObject private var ritualStore: RitualStore
    @EnvironmentObject private var currentStatusStore: CurrentStatusStore
    @EnvironmentObject private var whisperNoteStore: WhisperNoteStore
    @EnvironmentObject private var relationshipStore: RelationshipStore
    @EnvironmentObject private var accountSessionStore: AccountSessionStore
    @EnvironmentObject private var syncService: AppSyncService
    private let spaceItems = AppMockData.spaceSettingsItems
    private let personalItems = AppMockData.personalSettingsItems

    @State private var selectedDestination: SettingsDestination?
    @State private var pendingSpaceSettingsAction: SpaceSettingsEntryAction?
    @State private var isPresentingLogoutConfirmation = false

    private let insightColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                        topStatusCard

                        accountSyncSection

                        AppSectionCard(
                            title: "空间状态",
                            subtitle: "安静地看一眼，现在的你们把空间留到了哪里",
                            symbol: "sparkles"
                        ) {
                            LazyVGrid(columns: insightColumns, alignment: .leading, spacing: 10) {
                                ForEach(spaceInsights) { item in
                                    SpaceInsightCard(item: item)
                                }
                            }
                        }

                        SettingsSectionCard(
                            title: "空间相关",
                            subtitle: "属于你们两个人的设置与资料",
                            symbol: "person.2",
                            items: spaceItems,
                            onSelect: handleSelection(_:)
                        )

                        SettingsSectionCard(
                            title: "个人相关",
                            subtitle: "提醒、展示和隐私入口",
                            symbol: "person",
                            items: personalItems,
                            onSelect: handleSelection(_:)
                        )
                    }
                    .padding(AppTheme.Spacing.page)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: Binding(
                get: { selectedDestination == .spaceSettings },
                set: { isPresented in
                    if !isPresented {
                        selectedDestination = nil
                    }
                }
            )) {
                SpaceSettingsView(initialAction: pendingSpaceSettingsAction)
                    .onDisappear {
                        pendingSpaceSettingsAction = nil
                    }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedDestination == .anniversaryManagement },
                set: { isPresented in
                    if !isPresented {
                        selectedDestination = nil
                    }
                }
            )) {
                AnniversaryManagementView()
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedDestination == .accountSync },
                set: { isPresented in
                    if !isPresented {
                        selectedDestination = nil
                    }
                }
            )) {
                AccountSyncStatusView(onLoginCompletion: handleAccountLoginCompletion)
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedDestination == .login },
                set: { isPresented in
                    if !isPresented {
                        selectedDestination = nil
                    }
                }
            )) {
                AccountLoginView(onCompletion: handleAccountLoginCompletion)
            }
            .onAppear {
                handlePendingDeepLinkIfNeeded()
                Task {
                    await relationshipStore.refreshRemoteRelationshipStatusIfNeeded()
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
                        trigger: .meViewAppeared
                    )
                }
            }
            .onChange(of: navigationState.selectedTab) { _, _ in
                handlePendingDeepLinkIfNeeded()
                guard navigationState.selectedTab == .me else { return }
                Task {
                    await relationshipStore.refreshRemoteRelationshipStatusIfNeeded()
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
                        trigger: .meViewAppeared
                    )
                }
            }
            .onChange(of: navigationState.pendingDeepLink) { _, _ in
                handlePendingDeepLinkIfNeeded()
            }
            .confirmationDialog(
                "退出当前账号？",
                isPresented: $isPresentingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("退出登录", role: .destructive) {
                    performLogout()
                }

                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后会回到未登录状态，“我的”页顶部会重新显示登录卡片，当前共享关系和共享作用域也会一起收回到本地。")
            }
        }
    }

    private func handleSelection(_ item: SettingsItem) {
        switch item.destination {
        case .spaceSettings:
            pendingSpaceSettingsAction = nil
            selectedDestination = .spaceSettings
        case .anniversaryManagement:
            selectedDestination = .anniversaryManagement
        case .accountSync:
            selectedDestination = .accountSync
        case .login:
            selectedDestination = .login
        case .none:
            break
        }
    }

    private func handlePendingDeepLinkIfNeeded() {
        guard navigationState.selectedTab == .me else { return }
        guard navigationState.pendingDeepLink == .anniversaryManagement else { return }
        selectedDestination = .anniversaryManagement
        navigationState.consumePendingDeepLink(.anniversaryManagement)
    }

    private func handleAccountLoginCompletion(_ action: AccountLoginCompletionAction) {
        switch action {
        case .continueLocally:
            selectedDestination = nil
        case .returnToMainExperience:
            selectedDestination = nil
            navigationState.selectedTab = .home
        case .openRelationshipSetup:
            pendingSpaceSettingsAction = nil
            selectedDestination = .spaceSettings
        }
    }

    private func performLogout() {
        selectedDestination = nil
        pendingSpaceSettingsAction = nil
        syncService.logoutCurrentAccount()
    }

    @ViewBuilder
    private var topStatusCard: some View {
        if accountSessionStore.state.isLoggedIn {
            MeRelationshipHeaderCard(
                relationship: relationshipStore.state,
                accountDisplayName: accountSessionStore.state.account?.nickname ?? "已登录账号",
                accountDetailText: accountSessionStore.state.account?.detailText,
                onLogout: {
                    isPresentingLogoutConfirmation = true
                },
                onCreateSpace: {
                    pendingSpaceSettingsAction = .create
                    selectedDestination = .spaceSettings
                },
                onJoinSpace: {
                    pendingSpaceSettingsAction = .join
                    selectedDestination = .spaceSettings
                }
            )
        } else {
            LoggedOutLoginEntryCard(
                onLogin: {
                    selectedDestination = .login
                },
                onContinueLocally: {
                    selectedDestination = nil
                    navigationState.selectedTab = .home
                }
            )
        }
    }

    private var accountSyncSection: some View {
        let isLoggedIn = accountSessionStore.state.isLoggedIn

        return AppSectionCard(
            title: "保存与同步",
            subtitle: isLoggedIn
                ? "账号已经接入，但当前内容仍以本地保存和本地备份为主；云端状态会继续在这里承接。"
                : "现在仍以本地保存为主，需要时再登录账号或整理备份恢复即可。",
            symbol: "externaldrive"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    PageMetaPill(
                        text: "本地优先",
                        systemImage: "iphone",
                        emphasis: true
                    )
                    PageMetaPill(
                        text: relationshipStore.state.relationStatus.label,
                        systemImage: relationshipStore.state.relationStatus.symbol,
                        emphasis: relationshipStore.state.isBound
                    )
                    if syncService.status.mode != .localOnly || accountSessionStore.state.sessionSource != .none {
                        PageMetaPill(
                            text: "已保留准备状态",
                            systemImage: "icloud",
                            emphasis: false
                        )
                    }
                }

                Text(accountSyncOverviewText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(4)

                if isLoggedIn == false {
                    Text("现在先支持邮箱和密码登录；如果只是继续记录和查看，也可以直接先按本地方式使用。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }
            }
        }
    }

    private var spaceInsights: [SpaceInsight] {
        let state = relationshipStore.state

        switch state.relationStatus {
        case .unpaired:
            return [
                SpaceInsight(title: "关系状态", value: "未绑定", note: "还没有开始共享空间，先创建一个或输入邀请码加入。"),
                SpaceInsight(title: "共享空间", value: "未激活", note: "绑定完成后，这里会显示你们已经激活的双人空间。"),
                SpaceInsight(title: "下一步", value: "去设置", note: "主入口已经放在空间设置里，流程会从那里开始。")
            ]
        case .inviting:
            return [
                SpaceInsight(title: "关系状态", value: "邀请中", note: "邀请码已经生成，等 \(state.partnerDisplayName) 加入后就会正式激活。"),
                SpaceInsight(title: "邀请码", value: state.inviteCode ?? "--", note: "这是当前空间的邀请码，可以在设置页继续完成关系确认。"),
                SpaceInsight(title: "共享空间", value: "待激活", note: "空间已经创建好，下一步只差对方加入。")
            ]
        case .paired:
            return [
                SpaceInsight(title: "关系状态", value: "已绑定", note: "你们已经在同一个共享空间里继续记录和计划。"),
            SpaceInsight(title: "共享空间", value: "已激活", note: state.space?.title ?? "双人共享空间"),
            SpaceInsight(title: "伴侣", value: state.partnerDisplayName, note: "现在首页、愿望和生活记录都已经属于这个双人关系。")
            ]
        }
    }

    private var pageBackground: some View {
        ZStack(alignment: .top) {
            AppAtmosphereBackground(
                primaryGlow: AppTheme.Colors.softAccent.opacity(0.28),
                secondaryGlow: AppTheme.Colors.softAccentSecondary.opacity(0.22),
                primaryOffset: CGSize(width: -135, height: -255),
                secondaryOffset: CGSize(width: 135, height: -28)
            )

            topAtmosphere
        }
    }

    private var topAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.glow.opacity(0.16),
                    AppTheme.Colors.softAccentSecondary.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 340)
            .blur(radius: 10)
            .offset(y: -28)

            Circle()
                .fill(AppTheme.Colors.softAccent.opacity(0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 46)
                .offset(x: -102, y: -88)

            Circle()
                .fill(AppTheme.Colors.softAccentSecondary.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 126, y: -16)
        }
        .allowsHitTesting(false)
    }

    private var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    private var memories: [MemoryTimelineEntry] {
        memoryStore.entries(in: contentScope)
    }

    private var wishes: [PlaceWish] {
        wishStore.wishes(in: contentScope)
    }

    private var anniversaries: [AnniversaryItem] {
        anniversaryStore.anniversaries(in: contentScope)
    }

    private var totalContentCount: Int {
        memories.count + wishes.count + anniversaries.count
    }

    private var accountSyncOverviewText: String {
        if syncService.status.mode == .localOnly {
            return "当前空间里的 \(totalContentCount) 条内容都会先稳稳留在这台设备里；如果只是日常记录、查看或换机前留存，继续使用本地备份恢复就够了。需要连接账号时，可以从这里直接进入登录。"
        }

        return "当前只是保留一层云端准备状态，普通使用仍建议把这 \(totalContentCount) 条内容按本地保存和本地备份来理解。"
    }
}

private struct LoggedOutLoginEntryCard: View {
    let onLogin: () -> Void
    let onContinueLocally: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeroLabel(text: "余白账号", systemImage: "person.crop.circle")

            VStack(alignment: .leading, spacing: 8) {
                Text("登录后继续进入同一个共享空间")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text("账号登录、关系承接和后续共享都会沿着这份身份继续走下去。如果现在只想自己先记着，也可以先单人本地使用。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                PageMetaPill(text: "邮箱登录", systemImage: "envelope")
                PageMetaPill(text: "本地优先", systemImage: "iphone", emphasis: true)
            }

            HStack(spacing: 10) {
                Button(action: onLogin) {
                    PageCTAButton(
                        text: "登录",
                        systemImage: "person.crop.circle.badge.checkmark"
                    )
                }
                .buttonStyle(.plain)

                Button(action: onContinueLocally) {
                    PageActionPill(
                        text: "单人本地使用",
                        systemImage: "iphone"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.glow.opacity(0.36))
                    .frame(width: 190, height: 190)
                    .blur(radius: 28)
                    .offset(x: 120, y: -70)

                Circle()
                    .fill(AppTheme.Colors.softAccentSecondary.opacity(0.22))
                    .frame(width: 140, height: 140)
                    .blur(radius: 18)
                    .offset(x: -100, y: 90)
            }
        )
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
            cornerRadius: 28,
            borderColor: AppTheme.Colors.divider
        )
    }
}

private struct AccountSyncStatusView: View {
    @EnvironmentObject private var memoryStore: MemoryStore
    @EnvironmentObject private var wishStore: WishStore
    @EnvironmentObject private var anniversaryStore: AnniversaryStore
    @EnvironmentObject private var weeklyTodoStore: WeeklyTodoStore
    @EnvironmentObject private var tonightDinnerStore: TonightDinnerStore
    @EnvironmentObject private var ritualStore: RitualStore
    @EnvironmentObject private var currentStatusStore: CurrentStatusStore
    @EnvironmentObject private var whisperNoteStore: WhisperNoteStore
    @EnvironmentObject private var relationshipStore: RelationshipStore
    @EnvironmentObject private var accountSessionStore: AccountSessionStore
    @EnvironmentObject private var syncService: AppSyncService

    let onLoginCompletion: (AccountLoginCompletionAction) -> Void

    @State private var isPresentingPreviewSheet = false
    @State private var isPresentingBackupExporter = false
    @State private var isPresentingBackupImporter = false
    @State private var isPresentingImportConfirmation = false
    @State private var isPresentingAccountLoginPage = false
    @State private var isShowingDeveloperTools = false
    @State private var exportDocument = LocalBackupDocument(
        payload: LocalBackupService.makePayload(
            relationship: .demoDefault,
            memories: [],
            wishes: [],
            anniversaries: [],
            weeklyTodos: [],
            tonightDinners: [],
            rituals: [],
            currentStatuses: [],
            whisperNotes: []
        )
    )
    @State private var exportFilename = "余白-备份"
    @State private var pendingImportedBackup: LocalBackupPayload?
    @State private var backupFeedback: BackupFeedback?

    private let overviewColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    private let moduleTileMinHeight: CGFloat = 106
    private let moduleSurfaceMinHeight: CGFloat = 94

    var body: some View {
        ZStack {
            AppAtmosphereBackground(
                primaryGlow: AppTheme.Colors.softAccent.opacity(0.24),
                secondaryGlow: AppTheme.Colors.glow.opacity(0.18),
                primaryOffset: CGSize(width: -120, height: -250),
                secondaryOffset: CGSize(width: 125, height: -40)
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                    heroCard

                    accountAccessSection

                    syncStatusSection

                    backupSection

                    AppSectionCard(
                        title: "当前连接状态",
                        subtitle: "这些状态会继续承接账号、空间关系和云端结果，当前先用来把边界说明清楚。",
                        symbol: "arrow.triangle.2.circlepath.icloud"
                    ) {
                        VStack(spacing: 12) {
                            capabilityRow(
                                title: "账号会话层",
                                subtitle: accountSessionStore.state.isLoggedIn
                                    ? (accountSessionStore.state.authorization != nil
                                        ? "当前已经有一份可用账号 \(accountSessionStore.state.account?.nickname ?? "")，后续云端状态会继续从这里读取。"
                                        : "当前已经有账号会话 \(accountSessionStore.state.account?.nickname ?? "")，以后开启正式登录时会继续沿用。")
                                    : "当前还没有开启账号，但账号会话入口已经预留好。",
                                symbol: "iphone.gen3"
                            )

                            capabilityRow(
                                title: "云端状态边界",
                                subtitle: "这里会统一承接上传、下载和云端连接状态；测试环境接入工具会单独放在下方，不影响日常查看。",
                                symbol: "icloud"
                            )

                            capabilityRow(
                                title: "内容承接范围",
                                subtitle: "MemoryStore、WishStore 和 AnniversaryStore 继续负责本地真实数据；以后只需要把它们的内容快照交给这里即可。",
                                symbol: "arrow.triangle.2.circlepath"
                            )
                        }
                    }

                    AppSectionCard(
                        title: "当前使用方式",
                        subtitle: "这里集中说明本地保存、云端状态和当前边界，便于你们安心继续使用。",
                        symbol: "iphone"
                    ) {
                        VStack(spacing: 14) {
                            phaseLine(
                                title: "当前保存方式",
                                subtitle: "继续新增生活记录、愿望和纪念日；这些内容都会真实保存在本机，并按当前共享空间作用域读取。账号与同步页现在读到的也是这套真实本地状态。"
                            )

                            phaseLine(
                                title: "云端状态说明",
                                subtitle: syncService.status.detail
                            )

                            phaseLine(
                                title: "当前边界",
                                subtitle: "当前不包含手机号登录、验证码和实时自动同步；现在只补了一层低风险的自动推拉触发，手动同步入口仍然保留，方便继续联调和确认内容。"
                            )
                        }
                    }

#if DEBUG
                    developerToolsSection
#endif
                }
                .padding(AppTheme.Spacing.page)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("账号与同步")
        .secondaryPageNavigationStyle()
        .sheet(isPresented: $isPresentingPreviewSheet) {
            AccountSyncPreviewSheet(
                isBound: relationshipStore.state.isBound,
                partnerName: relationshipStore.state.partnerDisplayName
            )
        }
        .navigationDestination(isPresented: $isPresentingAccountLoginPage) {
            AccountLoginView(onCompletion: handleLoginCompletion)
        }
        .fileExporter(
            isPresented: $isPresentingBackupExporter,
            document: exportDocument,
            contentType: LocalBackupDocument.readableContentTypes.first ?? .json,
            defaultFilename: exportFilename
        ) { result in
            handleBackupExportResult(result)
        }
        .fileImporter(
            isPresented: $isPresentingBackupImporter,
            allowedContentTypes: LocalBackupDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleBackupImportSelection(result)
        }
        .confirmationDialog(
            "导入备份会覆盖当前空间的本地数据",
            isPresented: $isPresentingImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("覆盖导入", role: .destructive) {
                confirmBackupImport()
            }

            Button("取消", role: .cancel) {
                pendingImportedBackup = nil
            }
        } message: {
            if let pendingImportedBackup {
                Text(importConfirmationMessage(for: pendingImportedBackup))
            }
        }
        .task(id: refreshTaskKey) {
            await syncService.refreshRemoteSummary(for: contentScope)
            syncService.scheduleAutomaticPullIfPossible(
                scope: contentScope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore,
                trigger: .accountSyncAppeared
            )
        }
    }

    private var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    private var totalContentCount: Int {
        memoryStore.entries(in: contentScope).count
        + wishStore.wishes(in: contentScope).count
        + anniversaryStore.anniversaries(in: contentScope).count
    }

    private var weeklyTodoItems: [WeeklyTodoItem] {
        weeklyTodoStore.items(in: contentScope)
    }

    private var tonightDinnerItems: [TonightDinnerOption] {
        tonightDinnerStore.items(in: contentScope)
    }

    private var ritualItems: [RitualItem] {
        ritualStore.items(in: contentScope)
    }

    private var currentStatuses: [CurrentStatusItem] {
        currentStatusStore.items(in: contentScope)
    }

    private var whisperNotes: [WhisperNoteItem] {
        whisperNoteStore.items(in: contentScope)
    }

    private var manualSyncIdentityText: String {
        let sessionAccountId = accountSessionStore.state.account?.accountId ?? "未登录"
        let relationshipAccountId = relationshipStore.state.currentAccountId ?? "未对齐"
        let partnerUserId = relationshipStore.state.partner?.userId ?? "未绑定"
        let spaceId = relationshipStore.state.space?.spaceId ?? contentScope.spaceId

        return "当前账号 \(sessionAccountId)；关系归属 \(relationshipAccountId)；currentUser \(relationshipStore.state.currentUser.userId)；partner \(partnerUserId)；space \(spaceId)。"
    }

    private var refreshTaskKey: String {
        "\(contentScope.spaceId)-\(accountSessionStore.state.account?.accountId ?? "local")-\(syncService.status.mode.label)"
    }

    private var syncOverviewHeroTitle: String {
        syncService.status.mode == .localOnly ? "现在以本地保存为主" : "当前仍以本地保存为主"
    }

    private var syncOverviewHeroBody: String {
        if syncService.status.mode == .localOnly {
            return "生活记录、愿望和纪念日会先稳稳留在这台设备里；登录账号和同步状态入口都已经单独收好，不影响现在继续把日常留在本地。"
        }

        return "当前只是保留一层云端准备状态，用来承接后续接入和开发联调；普通使用仍建议以本地保存和本地备份恢复为准。"
    }

    private var heroCard: some View {
        let snapshot = syncService.buildSnapshot(
            memories: memoryStore.entries(in: contentScope),
            memoryTombstones: memoryStore.deletionTombstones(in: contentScope),
            wishes: wishStore.wishes(in: contentScope),
            wishTombstones: wishStore.deletionTombstones(in: contentScope),
            anniversaryTombstones: anniversaryStore.deletionTombstones(in: contentScope),
            anniversaries: anniversaryStore.anniversaries(in: contentScope),
            weeklyTodoTombstones: weeklyTodoStore.deletionTombstones(in: contentScope),
            weeklyTodos: weeklyTodoItems,
            tonightDinners: tonightDinnerItems,
            rituals: ritualItems,
            currentStatuses: currentStatuses,
            whisperNotes: whisperNotes,
            scope: contentScope
        )

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                PageHeroLabel(
                    text: "本地优先",
                    systemImage: "iphone"
                )

                Spacer(minLength: 12)

                PageMetaPill(
                    text: relationshipStore.state.isBound ? "共享空间中" : "本地空间",
                    systemImage: relationshipStore.state.isBound ? "person.2.fill" : "iphone",
                    emphasis: relationshipStore.state.isBound
                )

                if syncService.status.mode != .localOnly || syncService.status.hasRemoteContent {
                    PageMetaPill(
                        text: "已保留准备状态",
                        systemImage: "icloud",
                        emphasis: false
                    )
                }
            }

            Text(syncOverviewHeroTitle)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(syncOverviewHeroBody)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            LazyVGrid(columns: overviewColumns, alignment: .leading, spacing: 10) {
                syncInsightCard(
                    SpaceInsight(
                        title: "当前保存方式",
                        value: "本地优先",
                        note: syncService.status.mode == .localOnly
                            ? "日常记录、查看和换机前留存，优先依赖本机保存和下方的本地备份恢复。"
                            : "即使已经保留准备状态，普通使用仍建议按本地保存和本地备份来理解。"
                    )
                )

                syncInsightCard(
                    SpaceInsight(
                        title: "内容快照",
                        value: "\(snapshot.totalCount) 条",
                        note: "这里汇总了当前空间里的 \(snapshot.memoryCount) 段生活记录、\(snapshot.wishCount) 个愿望、\(snapshot.anniversaryCount) 个纪念日、\(snapshot.weeklyTodoCount) 条本周事项、\(snapshot.tonightDinnerCount) 个今晚吃什么候选、\(snapshot.ritualCount) 条小约定、\(snapshot.currentStatusCount) 条当前状态和 \(snapshot.whisperNoteCount) 条悄悄话。"
                    )
                )

                syncInsightCard(
                    SpaceInsight(
                        title: "共享范围",
                        value: relationshipStore.state.isBound ? relationshipStore.state.partnerDisplayName : "本地空间",
                        note: relationshipStore.state.isBound
                            ? "当前已与 \(relationshipStore.state.partnerDisplayName) 进入同一共享作用域，页面和内容都会按这段关系继续读取。"
                            : "当前仍使用本地作用域，内容会先保存在这台设备上。"
                    )
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    if syncService.status.mode != .localOnly {
                        Button {
                            syncService.returnToLocalMode()
                        } label: {
                            PageActionPill(
                                text: accountSessionStore.state.sessionSource == .demo ? "关闭准备状态" : "回到本地保存",
                                systemImage: accountSessionStore.state.sessionSource == .demo ? "xmark.circle" : "iphone"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isPresentingPreviewSheet = true
                    } label: {
                        PageActionPill(text: "查看说明", systemImage: "chevron.right")
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }

                moduleFootnote(accountSessionStore.state.sessionSource.productDescription)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.softAccent.opacity(0.38))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                    .offset(x: 120, y: -80)

                Circle()
                    .fill(AppTheme.Colors.glow.opacity(0.28))
                    .frame(width: 150, height: 150)
                    .blur(radius: 24)
                    .offset(x: -90, y: 120)
            }
        )
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
            cornerRadius: AppTheme.CornerRadius.hero,
            borderColor: AppTheme.Colors.divider
        )
    }

    private var accountAccessSection: some View {
        let isAuthenticated = accountSessionStore.state.sessionSource == .authenticated
        let account = accountSessionStore.state.account

        return AppSectionCard(
            title: isAuthenticated ? "当前账号" : "登录账号",
            subtitle: isAuthenticated
                ? "这份账号会继续承接当前会话、共享空间连接和后端鉴权。"
                : "先用邮箱和密码登录一份账号，后续共享空间连接和同步状态都会沿着这份会话继续承接。",
            symbol: isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle"
        ) {
            Button {
                isPresentingAccountLoginPage = true
            } label: {
                PageActionPill(
                    text: isAuthenticated ? "切换账号" : "登录账号",
                    systemImage: isAuthenticated ? "arrow.clockwise" : "person.crop.circle.badge.checkmark"
                )
            }
            .buttonStyle(.plain)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if let account {
                    modeCaption(
                        title: "\(account.nickname) 已连接",
                        subtitle: "\(account.providerName) · \(account.detailText)"
                    )

                    HStack(spacing: 8) {
                        PageMetaPill(
                            text: "账号已连接",
                            systemImage: "person.crop.circle.badge.checkmark",
                            emphasis: true
                        )
                        PageMetaPill(
                            text: syncService.status.mode == .localOnly ? "本地优先" : "同步状态已承接",
                            systemImage: syncService.status.mode == .localOnly ? "iphone" : "icloud"
                        )
                    }

                    moduleFootnote("后续 create / join space、真实 snapshot pull / push 和账号展示都会继续复用当前这份 authenticated session。")
                } else {
                    modeCaption(
                        title: "当前还没有登录账号",
                        subtitle: "当前先支持邮箱和密码登录。登录成功后，会直接进入现有账号会话，不会新起第二套 session。"
                    )

                    moduleFootnote("本轮只补正式登录入口，不包含注册、找回密码、验证码或第三方登录。")
                }
            }
        }
    }

    private var syncStatusSection: some View {
            AppSectionCard(
                title: "同步状态说明",
                subtitle: "登录成功后，会继续在这里承接当前会话、后端连接和同步状态；主体验仍以本地保存为主。",
                symbol: "icloud"
            ) {
            VStack(alignment: .leading, spacing: 14) {
                modeCaption(
                    title: "当前状态",
                    subtitle: syncService.status.mode == .localOnly
                        ? "现在仍以本机保存和本地备份恢复为主；如果需要连接账号，主入口已经放在上方。"
                        : "当前只是保留云端准备状态，普通使用仍建议以本地保存和备份恢复为准。"
                )

                LazyVGrid(columns: overviewColumns, alignment: .leading, spacing: 10) {
                    syncInsightCard(
                        SpaceInsight(
                            title: "当前模式",
                            value: syncService.status.mode.label,
                            note: syncService.status.mode == .localOnly
                                ? "内容仍优先保存在本机，日常使用更建议依赖下方的本地备份与恢复。"
                                : "这里仅保留状态承接，不代表云端已经作为正式能力对外开放。"
                        )
                    )

                    syncInsightCard(
                        SpaceInsight(
                            title: "当前连接",
                            value: syncService.status.availabilityLabel,
                            note: "开发接入和手动读写入口已经移到页面下方单独收纳，不打断普通使用。"
                        )
                    )

                    syncInsightCard(
                        SpaceInsight(
                            title: "当前说明",
                            value: syncService.status.hasRemoteContent ? "已保留准备状态" : "本地优先",
                            note: "如果只是日常记录、查看或换机前留存，优先使用本地保存和本地备份恢复即可。"
                        )
                    )
                }

                if let latestEventText = syncService.status.latestEventText {
                    HStack(spacing: 8) {
                        Image(systemName: syncService.status.latestErrorText == nil ? "checkmark.circle" : "exclamationmark.circle")
                            .font(.caption.weight(.semibold))

                        Text(syncService.status.latestErrorText ?? latestEventText)
                            .font(.footnote.weight(.medium))
                            .lineSpacing(3)
                    }
                    .foregroundStyle(syncService.status.latestErrorText == nil ? AppTheme.Colors.deepAccent : AppTheme.Colors.subtitle)
                }

                if syncService.status.hasPendingPulledContent,
                   let pendingText = syncService.status.pendingPulledContentText {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption.weight(.semibold))

                        Text(pendingText)
                            .font(.footnote.weight(.medium))
                            .lineSpacing(3)
                    }
                    .foregroundStyle(AppTheme.Colors.subtitle)
                }

                moduleFootnote(
                    "云端相关的测试环境接入、手动推送和读取能力仍保留在页面下方的独立区块里；这里先避免把它表达成已经正式开放的用户能力。"
                )
            }
        }
    }

    private var backupSection: some View {
        AppSectionCard(
            title: "本地备份与恢复",
            subtitle: "把当前空间的文字内容和基础信息导出成 JSON，作为本地备份文件；这和同步是两条不同的能力线。",
            symbol: "externaldrive"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                modeCaption(
                    title: "当前会导出的内容",
                    subtitle: "\(memoryStore.entries(in: contentScope).count) 段生活记录、\(wishStore.wishes(in: contentScope).count) 个愿望、\(anniversaryStore.anniversaries(in: contentScope).count) 个纪念日、\(weeklyTodoItems.count) 条本周事项、\(tonightDinnerItems.count) 个晚饭候选、\(ritualItems.count) 条小默契、\(currentStatuses.count) 条当前状态、\(whisperNotes.count) 张悄悄话，以及当前关系 / 共享空间基础信息。记录里附加的本地图片目前仍留在这台设备里，不包含在这份备份中。"
                )

                HStack(spacing: 10) {
                    Button {
                        prepareBackupExport()
                    } label: {
                        PageActionPill(text: "导出当前空间数据", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)

                    Button {
                        isPresentingBackupImporter = true
                    } label: {
                        PageActionPill(text: "导入备份（覆盖当前空间）", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }

                if let backupFeedback {
                    HStack(spacing: 8) {
                        Image(systemName: backupFeedback.isError ? "exclamationmark.circle" : "checkmark.circle")
                            .font(.caption.weight(.semibold))

                        Text(backupFeedback.message)
                            .font(.footnote.weight(.medium))
                            .lineSpacing(3)
                    }
                    .foregroundStyle(backupFeedback.isError ? AppTheme.Colors.subtitle : AppTheme.Colors.deepAccent)
                }

                moduleFootnote("导入会覆盖当前空间的本地数据，不做 merge；恢复回来的是文字内容与空间基础信息，之前附加在记录里的本地图片目前不会随备份一起恢复。如果备份文件来自另一段关系或另一套共享空间，导入后也会一并恢复那份关系与空间基础信息。")
            }
        }
    }

    private func displayText(for date: Date?) -> String {
        guard let date else { return "--" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func prepareBackupExport() {
        let exportedAt = Date()
        let payload = LocalBackupService.makePayload(
            relationship: relationshipStore.state,
            memories: memoryStore.entries(in: contentScope),
            wishes: wishStore.wishes(in: contentScope),
            anniversaries: anniversaryStore.anniversaries(in: contentScope),
            weeklyTodos: weeklyTodoItems,
            tonightDinners: tonightDinnerItems,
            rituals: ritualItems,
            currentStatuses: currentStatuses,
            whisperNotes: whisperNotes,
            exportedAt: exportedAt
        )

        exportDocument = LocalBackupDocument(payload: payload)
        exportFilename = LocalBackupService.defaultFilename(
            relationship: relationshipStore.state,
            exportedAt: exportedAt
        )
        isPresentingBackupExporter = true
    }

    private func handleBackupExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupFeedback = BackupFeedback(
                message: "备份文件已生成，现在可以保存到“文件”或分享出去，作为当前空间的文字内容与基础信息备份。",
                isError: false
            )
        case let .failure(error):
            guard !isUserCancelled(error) else { return }
            backupFeedback = BackupFeedback(
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    private func handleBackupImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            do {
                let payload = try LocalBackupDocument.read(from: url)
                pendingImportedBackup = payload
                isPresentingImportConfirmation = true
            } catch {
                backupFeedback = BackupFeedback(
                    message: error.localizedDescription,
                    isError: true
                )
            }
        case let .failure(error):
            guard !isUserCancelled(error) else { return }
            backupFeedback = BackupFeedback(
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    private func confirmBackupImport() {
        guard let pendingImportedBackup else { return }

        do {
            let summary = try LocalBackupService.restore(
                pendingImportedBackup,
                currentScope: contentScope,
                relationshipStore: relationshipStore,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore
            )
            backupFeedback = BackupFeedback(message: summary.message, isError: false)
            self.pendingImportedBackup = nil
        } catch {
            backupFeedback = BackupFeedback(
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    private func importConfirmationMessage(for payload: LocalBackupPayload) -> String {
        "这份备份导出于 \(payload.exportedAt.formatted(date: .abbreviated, time: .shortened))，包含 \(payload.memories.count) 段生活记录、\(payload.wishes.count) 个愿望、\(payload.anniversaries.count) 个纪念日、\(payload.weeklyTodos.count) 条本周事项、\(payload.tonightDinners.count) 个晚饭候选、\(payload.rituals.count) 条小默契、\(payload.currentStatuses.count) 条当前状态，以及 \(payload.restoredWhisperNotes.count) 张悄悄话。继续后会覆盖当前空间本地数据；记录里之前附加的本地图片不会通过这次导入恢复。"
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.userCancelled.rawValue
    }

    private var developerToolsSection: some View {
        AppSectionCard(
            title: "开发者入口",
            subtitle: "仅在需要联调或验证当前设备状态时再展开，日常使用可以忽略。",
            symbol: "wrench.and.screwdriver"
        ) {
            DisclosureGroup(isExpanded: $isShowingDeveloperTools) {
                VStack(alignment: .leading, spacing: 12) {
                    rehearsalEntry
                }
                .padding(.top, 12)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isShowingDeveloperTools ? "收起开发者工具" : "展开开发者工具")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text("这里保留联调与快照验证入口，和上面的正式账号路径分开收纳。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }
            }
            .tint(AppTheme.Colors.deepAccent)
        }
    }

    private func handleLoginCompletion(_ action: AccountLoginCompletionAction) {
        isPresentingAccountLoginPage = false
        onLoginCompletion(action)
    }

    private var rehearsalEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            modeCaption(
                title: "手动接入",
                subtitle: "用于连接当前公网测试环境并验证快照读写；仅供当前设备测试，不代表正式生产环境。"
            )

            modeCaption(
                title: "当前联调身份",
                subtitle: manualSyncIdentityText
            )

            HStack(spacing: 10) {
                Button {
                    Task {
                        await syncService.connectLocalBackendDemoAccount()
                    }
                } label: {
                    PageActionPill(
                        text: accountSessionStore.state.authorization != nil ? "重新使用测试账号登录" : "使用测试账号登录",
                        systemImage: "wrench.and.screwdriver"
                    )
                }
                .buttonStyle(.plain)
                .disabled(syncService.status.isSyncing)

                Button {
                    Task {
                        await syncService.pushCurrentScopeContentToLocalBackend(
                            memories: memoryStore.entries(in: contentScope),
                            memoryTombstones: memoryStore.deletionTombstones(in: contentScope),
                            wishes: wishStore.wishes(in: contentScope),
                            wishTombstones: wishStore.deletionTombstones(in: contentScope),
                            anniversaryTombstones: anniversaryStore.deletionTombstones(in: contentScope),
                            anniversaries: anniversaryStore.anniversaries(in: contentScope),
                            weeklyTodoStore: weeklyTodoStore,
                            tonightDinnerStore: tonightDinnerStore,
                            ritualStore: ritualStore,
                            currentStatusStore: currentStatusStore,
                            whisperNoteStore: whisperNoteStore,
                            scope: contentScope
                        )
                    }
                } label: {
                    PageActionPill(
                        text: "发送当前快照到测试环境",
                        systemImage: "arrow.up.circle"
                    )
                }
                .buttonStyle(.plain)
                .disabled(accountSessionStore.state.sessionSource != .authenticated || syncService.status.isSyncing)

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        _ = await syncService.pullAndApplyCurrentScopeContentFromLocalBackend(
                            scope: contentScope,
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
                } label: {
                    PageActionPill(
                        text: "从测试环境读取快照",
                        systemImage: "arrow.down.circle"
                    )
                }
                .buttonStyle(.plain)
                .disabled(accountSessionStore.state.sessionSource != .authenticated || syncService.status.isSyncing)

                Button {
                    let payload = AccountSyncRehearsalFixtures.remoteSnapshotPayload(
                        scope: contentScope,
                        relationship: relationshipStore.state,
                        memories: memoryStore.entries(in: contentScope),
                        wishes: wishStore.wishes(in: contentScope),
                        wishTombstones: wishStore.deletionTombstones(in: contentScope),
                        anniversaryTombstones: anniversaryStore.deletionTombstones(in: contentScope),
                        anniversaries: anniversaryStore.anniversaries(in: contentScope),
                        weeklyTodoTombstones: weeklyTodoStore.deletionTombstones(in: contentScope),
                        weeklyTodos: weeklyTodoItems,
                        tonightDinners: tonightDinnerItems,
                        rituals: ritualItems,
                        currentStatuses: currentStatuses,
                        whisperNotes: whisperNotes
                    )

                    _ = syncService.rehearseRemoteSnapshotPayload(
                        payload,
                        to: contentScope,
                        memoryStore: memoryStore,
                        wishStore: wishStore,
                        anniversaryStore: anniversaryStore,
                        weeklyTodoStore: weeklyTodoStore,
                        tonightDinnerStore: tonightDinnerStore,
                        ritualStore: ritualStore,
                        currentStatusStore: currentStatusStore,
                        whisperNoteStore: whisperNoteStore
                    )
                } label: {
                    PageActionPill(text: "本地演练同步返回", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(accountSessionStore.state.sessionSource != .authenticated || syncService.status.isSyncing)

                Spacer(minLength: 0)
            }

            moduleFootnote("这里的手动同步会先按当前 authenticated session 对齐 accountId / currentUserId / spaceId，再直接发送真实的 PUT 或 GET /spaces/{spaceId}/snapshot。读取入口会把当前快照链路里已经接入的内容直接应用到本地；最右侧入口仍是本地演练数据，不会真正请求后端。")
        }
    }

    private func modeCaption(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
    }

    private func capabilityRow(title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppIconBadge(
                symbol: symbol,
                fill: AppTheme.Colors.softAccent.opacity(0.3),
                size: 40,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AccountSyncInfoSurface(minHeight: moduleSurfaceMinHeight))
    }

    private func phaseLine(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.title)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AccountSyncInfoSurface(minHeight: moduleSurfaceMinHeight))
    }

    private func syncInsightCard(_ item: SpaceInsight) -> some View {
        SpaceInsightCard(
            item: item,
            minHeight: moduleTileMinHeight,
            fixedHeight: 118,
            noteLineLimit: 3
        )
    }

    private func moduleFootnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.subtitle)
            .lineSpacing(3)
    }
}

private struct BackupFeedback {
    let message: String
    let isError: Bool
}

private enum AccountLoginCompletionAction {
    case continueLocally
    case openRelationshipSetup
    case returnToMainExperience
}

private struct AccountLoginView: View {
    @EnvironmentObject private var syncService: AppSyncService
    @EnvironmentObject private var relationshipStore: RelationshipStore

    let onCompletion: (AccountLoginCompletionAction) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            AppAtmosphereBackground(
                primaryGlow: AppTheme.Colors.softAccent.opacity(0.28),
                secondaryGlow: AppTheme.Colors.glow.opacity(0.2),
                primaryOffset: CGSize(width: -120, height: -240),
                secondaryOffset: CGSize(width: 130, height: -20)
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                    heroCard
                    loginFormCard
                    reassuranceCard
                }
                .padding(AppTheme.Spacing.page)
                .padding(.bottom, 124)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .secondaryPageNavigationStyle()
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeroLabel(text: "余白账号", systemImage: "sparkles")

            VStack(alignment: .leading, spacing: 8) {
                Text("把你们的日常继续留在同一个空间")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text("登录后，关系连接、共享空间和后续承接都会沿着这份账号继续往下走。现在先支持邮箱和密码登录。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(4)
            }

            HStack(spacing: 8) {
                PageMetaPill(text: "邮箱登录", systemImage: "envelope")
                PageMetaPill(text: "本地优先", systemImage: "iphone", emphasis: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.glow.opacity(0.34))
                    .frame(width: 184, height: 184)
                    .blur(radius: 26)
                    .offset(x: 120, y: -80)

                Circle()
                    .fill(AppTheme.Colors.softAccentSecondary.opacity(0.18))
                    .frame(width: 148, height: 148)
                    .blur(radius: 20)
                    .offset(x: -96, y: 88)
            }
        )
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
            cornerRadius: AppTheme.CornerRadius.hero,
            borderColor: AppTheme.Colors.divider
        )
    }

    private var loginFormCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("登录信息")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            VStack(spacing: 12) {
                accountInputField(
                    title: "邮箱",
                    text: $email,
                    prompt: "输入你的邮箱",
                    textContentType: .username,
                    keyboardType: .emailAddress,
                    isSecure: false
                )

                accountInputField(
                    title: "密码",
                    text: $password,
                    prompt: "输入你的密码",
                    textContentType: .password,
                    keyboardType: .default,
                    isSecure: true
                )
            }

            if let errorText, errorText.isEmpty == false {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.primary),
            cornerRadius: AppTheme.CornerRadius.large,
            borderColor: AppTheme.Colors.divider
        )
    }

    private var reassuranceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("现在还可以单人本地使用")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("如果只是想继续记录、查看或整理现在的内容，也可以先不登录。内容会先稳稳留在这台设备里，需要时再连接账号。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.large,
            borderColor: AppTheme.Colors.divider
        )
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(AppTheme.Colors.title)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.footnote.weight(.semibold))
                    }

                    Text(isSubmitting ? "登录中" : "登录")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Colors.title)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
            .disabled(canSubmit == false || isSubmitting)
            .opacity(canSubmit == false || isSubmitting ? 0.72 : 1)

            Button {
                guard isSubmitting == false else { return }
                onCompletion(.continueLocally)
            } label: {
                Text("单人本地使用")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Colors.deepAccent)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.Colors.cardSurface(.tertiary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
            .disabled(isSubmitting)
        }
        .padding(.horizontal, AppTheme.Spacing.page)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var canSubmit: Bool {
        normalizedEmail.isEmpty == false && normalizedPassword.isEmpty == false
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func accountInputField(
        title: String,
        text: Binding<String>,
        prompt: String,
        textContentType: UITextContentType?,
        keyboardType: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Group {
                if isSecure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                        .keyboardType(keyboardType)
                }
            }
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body)
            .foregroundStyle(AppTheme.Colors.title)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.cardSurface(.secondary))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }

    private func submit() {
        guard canSubmit else {
            errorText = "请先填写邮箱和密码。"
            return
        }

        isSubmitting = true
        errorText = nil

        Task {
            do {
                let payload = try await syncService.loginWithBackend(
                    email: normalizedEmail,
                    password: normalizedPassword
                )
                await relationshipStore.adoptAuthenticatedRelationship(
                    activeSpaceID: payload.activeSpaceId
                )

                let nextAction = relationshipStore.state.isBound ? AccountLoginCompletionAction.returnToMainExperience : .openRelationshipSetup
                await MainActor.run {
                    isSubmitting = false
                    onCompletion(nextAction)
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

private enum AccountSyncRehearsalFixtures {
    private static let remoteMemoryID = UUID(uuidString: "1D27798A-0C77-44B5-A862-B2FC387A7E16")!
    private static let remoteWishID = UUID(uuidString: "39FA9A60-4E54-455F-A900-C1FC31B48E0F")!
    private static let remoteAnniversaryID = UUID(uuidString: "98E1E0B9-6FAF-4A0E-8B4F-C8A66879AA50")!
    private static let remoteTonightDinnerID = UUID(uuidString: "A41E3B50-53A0-4A63-9EAB-62A6E2A8645A")!
    private static let remoteRitualID = UUID(uuidString: "C60B2B14-AE2F-4706-8A85-38A9991A9F6A")!
    private static let remoteCurrentStatusID = UUID(uuidString: "F1A77AA1-77C0-45AC-A562-B0E670B5E8E9")!
    private static let remoteWhisperNoteID = UUID(uuidString: "29B8C146-4A59-4D9D-9DF2-7B532001B894")!

    static func authenticatedPayload(currentNickname: String) -> AuthenticatedAccountPayload {
        let trimmedName = currentNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? "我" : trimmedName
        let normalizedID = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        return AuthenticatedAccountPayload(
            accountId: "acct-auth-rehearsal-\(normalizedID)",
            displayName: displayName,
            providerName: "余白",
            accountHint: "本地 mock 真实登录返回",
            accessToken: nil,
            activeSpaceId: nil
        )
    }

    static func remoteSnapshotPayload(
        scope: AppContentScope,
        relationship: CoupleRelationshipState,
        memories: [MemoryTimelineEntry],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone] = [],
        anniversaryTombstones: [AnniversaryDeletionTombstone] = [],
        anniversaries: [AnniversaryItem],
        weeklyTodoTombstones: [WeeklyTodoDeletionTombstone] = [],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem]
    ) -> RemoteSyncSnapshotPayload {
        let now = Date()
        let rehearsalMemory = MemoryTimelineEntry(
            id: remoteMemoryID,
            title: "云端返回演练：一起散步回家",
            detail: "这条内容不是新功能，只是用来验证未来真实 sync API 返回后，是否真的能映射并写回当前本地 store。",
            date: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
            category: .daily,
            imageLabel: "夜晚散步",
            mood: "放松",
            location: relationship.spaceDisplayTitle,
            weather: "晚风",
            isFeatured: true,
            spaceId: scope.spaceId,
            createdByUserId: scope.partnerUserId ?? scope.currentUserId,
            createdAt: now,
            updatedAt: now,
            syncStatus: .synced
        )
        let rehearsalWish = PlaceWish(
            id: remoteWishID,
            title: "云端返回演练：周末去看海",
            detail: "用一份本地 mock 的真实返回，验证 RemoteSyncSnapshotPayload 能否顺着当前链路进入愿望 store。",
            note: "这条只用于演练真实接入前的承接路径。",
            category: .travel,
            status: .planning,
            targetText: "这个月",
            symbol: WishCategory.travel.symbol,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: now,
            updatedAt: now,
            syncStatus: .synced
        )
        let rehearsalAnniversary = AnniversaryItem(
            id: remoteAnniversaryID,
            title: "云端返回演练日",
            date: now,
            category: .custom,
            note: "这条纪念日只用于验证同步返回内容能否顺着当前链路写回本地。",
            cadence: .yearly,
            spaceId: scope.spaceId,
            createdByUserId: scope.currentUserId,
            createdAt: now,
            updatedAt: now,
            syncStatus: .synced
        )
        let rehearsalWeeklyTodo = WeeklyTodoItem(
            id: UUID(uuidString: "55555555-6666-7777-8888-999999999999") ?? UUID(),
            title: "云端返回演练：一起整理本周事项",
            isCompleted: false,
            scheduledDate: Calendar.current.date(byAdding: .day, value: 2, to: now),
            owner: .both,
            spaceId: scope.spaceId,
            createdByUserId: scope.partnerUserId ?? scope.currentUserId,
            createdAt: now,
            updatedAt: now,
            syncStatus: .synced
        )
        let rehearsalTonightDinner = TonightDinnerOption(
            id: remoteTonightDinnerID,
            title: "云端返回演练：番茄牛腩面",
            note: "这条只用于验证 TonightDinner 能否顺着 snapshot pull/apply 写回本地 store。",
            status: .candidate,
            createdAt: now,
            decidedAt: nil,
            createdByUserId: scope.partnerUserId ?? scope.currentUserId,
            spaceId: scope.spaceId,
            syncStatus: .synced
        )
        let rehearsalRitual = RitualItem(
            id: remoteRitualID,
            title: "云端返回演练：到家先抱一下",
            kind: .promise,
            isCompleted: false,
            note: "这条只用于验证 Ritual 能否顺着 snapshot pull/apply 写回本地 store。",
            createdAt: now,
            updatedAt: now,
            createdByUserId: scope.partnerUserId ?? scope.currentUserId,
            spaceId: scope.spaceId,
            syncStatus: .synced
        )
        let rehearsalCurrentStatus = CurrentStatusItem(
            id: remoteCurrentStatusID,
            userId: scope.partnerUserId ?? scope.currentUserId,
            displayText: "云端返回演练：想你，等你一起吃饭",
            tone: .powderPink,
            effectiveScope: .today,
            spaceId: scope.spaceId,
            updatedAt: now
        )
        let rehearsalWhisperNote = WhisperNoteItem(
            id: remoteWhisperNoteID,
            content: "云端返回演练：今晚回家后记得抱一下我。",
            createdAt: now,
            createdByUserId: scope.partnerUserId ?? scope.currentUserId,
            spaceId: scope.spaceId,
            syncStatus: .synced
        )

        return RemoteSyncSnapshotPayload(
            snapshotId: "remote-snapshot-rehearsal-\(scope.spaceId)",
            spaceId: scope.spaceId,
            currentUserId: scope.currentUserId,
            partnerUserId: scope.partnerUserId,
            isSharedSpace: scope.isSharedSpace,
            memories: merging(rehearsalMemory, into: markAsSynced(memories, updatedAt: now)),
            memoryTombstones: [],
            wishes: merging(rehearsalWish, into: markAsSynced(wishes, updatedAt: now)),
            wishTombstones: wishTombstones,
            anniversaryTombstones: anniversaryTombstones,
            anniversaries: merging(rehearsalAnniversary, into: markAsSynced(anniversaries, updatedAt: now)),
            weeklyTodoTombstones: weeklyTodoTombstones,
            weeklyTodos: merging(rehearsalWeeklyTodo, into: markAsSynced(weeklyTodos, updatedAt: now)),
            tonightDinners: merging(rehearsalTonightDinner, into: markAsSynced(tonightDinners)),
            rituals: merging(rehearsalRitual, into: markAsSynced(rituals, updatedAt: now)),
            currentStatuses: merging(rehearsalCurrentStatus, into: markAsSynced(currentStatuses, updatedAt: now)),
            whisperNotes: merging(rehearsalWhisperNote, into: markAsSynced(whisperNotes)),
            relationStatus: relationship.relationStatus,
            updatedAt: now
        )
    }

    private static func merging(_ rehearsalItem: MemoryTimelineEntry, into items: [MemoryTimelineEntry]) -> [MemoryTimelineEntry] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: PlaceWish, into items: [PlaceWish]) -> [PlaceWish] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: AnniversaryItem, into items: [AnniversaryItem]) -> [AnniversaryItem] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: WeeklyTodoItem, into items: [WeeklyTodoItem]) -> [WeeklyTodoItem] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: TonightDinnerOption, into items: [TonightDinnerOption]) -> [TonightDinnerOption] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: RitualItem, into items: [RitualItem]) -> [RitualItem] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: CurrentStatusItem, into items: [CurrentStatusItem]) -> [CurrentStatusItem] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func merging(_ rehearsalItem: WhisperNoteItem, into items: [WhisperNoteItem]) -> [WhisperNoteItem] {
        [rehearsalItem] + items.filter { $0.id != rehearsalItem.id }
    }

    private static func markAsSynced(_ items: [MemoryTimelineEntry], updatedAt: Date) -> [MemoryTimelineEntry] {
        items.map { item in
            MemoryTimelineEntry(
                id: item.id,
                title: item.title,
                detail: item.detail,
                date: item.date,
                category: item.category,
                imageLabel: item.imageLabel,
                photoFilename: item.photoFilename,
                mood: item.mood,
                location: item.location,
                weather: item.weather,
                isFeatured: item.isFeatured,
                spaceId: item.spaceId,
                createdByUserId: item.createdByUserId,
                createdAt: item.createdAt,
                updatedAt: updatedAt,
                syncStatus: .synced
            )
        }
    }

    private static func markAsSynced(_ items: [PlaceWish], updatedAt: Date) -> [PlaceWish] {
        items.map { item in
            PlaceWish(
                id: item.id,
                title: item.title,
                detail: item.detail,
                note: item.note,
                category: item.category,
                status: item.status,
                targetText: item.targetText,
                symbol: item.symbol,
                spaceId: item.spaceId,
                createdByUserId: item.createdByUserId,
                createdAt: item.createdAt,
                updatedAt: updatedAt,
                syncStatus: .synced
            )
        }
    }

    private static func markAsSynced(_ items: [AnniversaryItem], updatedAt: Date) -> [AnniversaryItem] {
        items.map { item in
            AnniversaryItem(
                id: item.id,
                title: item.title,
                date: item.date,
                category: item.category,
                note: item.note,
                cadence: item.cadence,
                spaceId: item.spaceId,
                createdByUserId: item.createdByUserId,
                createdAt: item.createdAt,
                updatedAt: updatedAt,
                syncStatus: .synced
            )
        }
    }

    private static func markAsSynced(_ items: [WeeklyTodoItem], updatedAt: Date) -> [WeeklyTodoItem] {
        items.map { item in
            WeeklyTodoItem(
                id: item.id,
                title: item.title,
                isCompleted: item.isCompleted,
                scheduledDate: item.scheduledDate,
                owner: item.owner,
                spaceId: item.spaceId,
                createdByUserId: item.createdByUserId,
                createdAt: item.createdAt,
                updatedAt: updatedAt,
                syncStatus: .synced
            )
        }
    }

    private static func markAsSynced(_ items: [TonightDinnerOption]) -> [TonightDinnerOption] {
        items.map { item in
            TonightDinnerOption(
                id: item.id,
                title: item.title,
                note: item.note,
                status: item.status,
                createdAt: item.createdAt,
                decidedAt: item.decidedAt,
                createdByUserId: item.createdByUserId,
                spaceId: item.spaceId,
                syncStatus: .synced
            )
        }
    }

    private static func markAsSynced(_ items: [RitualItem], updatedAt: Date) -> [RitualItem] {
        items.map { item in
            RitualItem(
                id: item.id,
                title: item.title,
                kind: item.kind,
                isCompleted: item.isCompleted,
                note: item.note,
                createdAt: item.createdAt,
                updatedAt: updatedAt,
                createdByUserId: item.createdByUserId,
                spaceId: item.spaceId,
                syncStatus: .synced
            )
        }
    }

    private static func markAsSynced(_ items: [CurrentStatusItem], updatedAt: Date) -> [CurrentStatusItem] {
        items.map { item in
            CurrentStatusItem(
                id: item.id,
                userId: item.userId,
                displayText: item.displayText,
                tone: item.tone,
                effectiveScope: item.effectiveScope,
                spaceId: item.spaceId,
                updatedAt: updatedAt
            )
        }
    }

    private static func markAsSynced(_ items: [WhisperNoteItem]) -> [WhisperNoteItem] {
        items.map { item in
            WhisperNoteItem(
                id: item.id,
                content: item.content,
                createdAt: item.createdAt,
                createdByUserId: item.createdByUserId,
                spaceId: item.spaceId,
                syncStatus: .synced
            )
        }
    }
}

private struct AccountSyncInfoSurface: ViewModifier {
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .appCardSurface(
                AppTheme.Colors.cardSurface(.secondary),
                cornerRadius: AppTheme.CornerRadius.medium
            )
    }
}

private struct AccountSyncPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let isBound: Bool
    let partnerName: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppAtmosphereBackground(
                    primaryGlow: AppTheme.Colors.softAccent.opacity(0.22),
                    secondaryGlow: AppTheme.Colors.glow.opacity(0.16),
                    primaryOffset: CGSize(width: -110, height: -220),
                    secondaryOffset: CGSize(width: 110, height: -30)
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        PageHeroLabel(text: "本地优先", systemImage: "iphone")

                        Text("当前以本地保存和备份恢复为主")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text(isBound
                             ? "现在你们已经在同一个共享空间里继续记录。账号与同步页会继续说明当前保存方式、云端状态，以及和 \(partnerName) 一起使用时的内容范围。"
                             : "现在的内容会先留在本机；这里主要用来说明当前保存方式、备份恢复入口和云端状态边界。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(4)

                        previewLine(
                            title: "本地内容继续积累",
                            subtitle: "生活记录、愿望和纪念日会按当前空间作用域真实保存，页面里看到的就是这份本地状态。"
                        )

                        previewLine(
                            title: "共享空间范围清楚",
                            subtitle: isBound
                                ? "已经绑定好的双人关系会继续共用同一份空间内容，首页和二级页也会按这个范围展示。"
                                : "未绑定时会先以本地空间使用，等进入双人关系后再切到共享空间范围。"
                        )

                        previewLine(
                            title: "备份与状态分开说明",
                            subtitle: "本地备份恢复和云端状态是两条独立能力线，都会在账号与同步页里清楚展示。"
                        )

                        Button {
                            dismiss()
                        } label: {
                            PageCTAButton(text: "知道了", systemImage: "checkmark")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(AppTheme.Spacing.page)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("账号与同步说明")
            .secondaryPageNavigationStyle()
        }
        .presentationDetents([.medium, .large])
    }

    private func previewLine(title: String, subtitle: String) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AccountSyncInfoSurface(minHeight: 94))
    }
}
