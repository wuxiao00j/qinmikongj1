import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @EnvironmentObject private var memoryStore: MemoryStore
    @EnvironmentObject private var wishStore: WishStore
    @EnvironmentObject private var anniversaryStore: AnniversaryStore
    @EnvironmentObject private var weeklyTodoStore: WeeklyTodoStore
    @EnvironmentObject private var currentStatusStore: CurrentStatusStore
    @EnvironmentObject private var whisperNoteStore: WhisperNoteStore
    @EnvironmentObject private var pageCardOrderStore: PageCardOrderStore
    @EnvironmentObject private var relationshipStore: RelationshipStore

    @State private var isPresentingStatusEditor = false
    @State private var isPresentingCardOrderEditor = false
    @State private var isPresentingWhisperComposer = false
    @State private var isPresentingWhisperList = false
    @State private var editingWhisperItem: WhisperNoteItem?
    @State private var pendingDeleteWhisperItem: WhisperNoteItem?

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                        HomeCoupleHeaderCard(
                            couple: homeCouple,
                            milestoneText: heroMilestoneText,
                            currentUserStatus: currentUserDailyStatus,
                            partnerStatus: partnerDailyStatus,
                            sharedStatus: heroSharedStatus,
                            myStatusActionTitle: myStatus == nil ? "写一句近况" : "更新我的近况",
                            onEditMyStatus: {
                                isPresentingStatusEditor = true
                            }
                        )

                        spaceActivityHeader

                        ForEach(pageCardOrderStore.homeOrder) { cardID in
                            homeSortableCard(cardID)
                        }

                        PageSectionHeader(
                            title: "轻一点的收尾",
                            subtitle: "把氛围留在最后，让首页不是停在按钮上。"
                        )

                        gentleSummaryCard
                    }
                    .padding(.horizontal, AppTheme.Spacing.page)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isPresentingWhisperList) {
                WhisperListView()
            }
            .sheet(isPresented: $isPresentingStatusEditor) {
                CurrentStatusEditorSheet(
                    initialStatus: myStatus,
                    onSave: { displayText, tone, effectiveScope in
                        currentStatusStore.upsert(
                            displayText: displayText,
                            tone: tone,
                            effectiveScope: effectiveScope,
                            for: relationshipStore.state.currentUser.userId,
                            in: contentScope
                        )
                    },
                    onClear: myStatus == nil ? nil : {
                        currentStatusStore.clearStatus(
                            for: relationshipStore.state.currentUser.userId,
                            in: contentScope
                        )
                    }
                )
            }
            .sheet(isPresented: $isPresentingCardOrderEditor) {
                CardOrderEditorSheet(
                    title: "调整首页卡片顺序",
                    subtitle: "首页 hero 和页面收尾会保持固定；这里只调整中间几张内容预览卡的先后顺序。",
                    items: homeCardOrderBinding,
                    onReset: {
                        pageCardOrderStore.resetHomeOrder()
                    },
                    titleForItem: \.title,
                    subtitleForItem: \.subtitle,
                    symbolForItem: \.symbol
                )
            }
            .sheet(isPresented: $isPresentingWhisperComposer) {
                WhisperComposerSheet(partnerName: relationshipStore.state.partnerDisplayName) { content in
                    whisperNoteStore.add(
                        WhisperNoteItem(content: content),
                        in: contentScope
                    )
                }
            }
            .sheet(item: $editingWhisperItem) { item in
                WhisperComposerSheet(
                    partnerName: relationshipStore.state.partnerDisplayName,
                    existingItem: item
                ) { content in
                    whisperNoteStore.update(
                        WhisperNoteItem(
                            id: item.id,
                            content: content,
                            createdAt: item.createdAt,
                            createdByUserId: item.createdByUserId,
                            spaceId: item.spaceId,
                            syncStatus: item.syncStatus
                        ),
                        in: contentScope
                    )
                }
            }
            .alert(
                "删除这张悄悄话？",
                isPresented: whisperDeleteAlertBinding,
                presenting: pendingDeleteWhisperItem
            ) { item in
                Button("删除", role: .destructive) {
                    whisperNoteStore.delete(item.id, in: contentScope)
                    pendingDeleteWhisperItem = nil
                }
                Button("取消", role: .cancel) {}
            } message: { item in
                Text("“\(item.previewText)”会从当前空间的小纸条里移除。")
            }
        }
    }
}

private extension HomeView {
    var homeCardOrderBinding: Binding<[HomeSortableCardID]> {
        Binding(
            get: { pageCardOrderStore.homeOrder },
            set: { pageCardOrderStore.setHomeOrder($0) }
        )
    }

    var spaceActivityHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            PageSectionHeader(
                title: "空间里正在发生",
                subtitle: "先看一眼重要的时间、正在靠近的愿望、最近留下来的生活记录，还有那些留给对方的小纸条。"
            )

            Spacer(minLength: 0)

            Button {
                isPresentingCardOrderEditor = true
            } label: {
                PageActionPill(text: "调整顺序", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func homeSortableCard(_ cardID: HomeSortableCardID) -> some View {
        switch cardID {
        case .anniversary:
            anniversaryPreviewCard
        case .wish:
            wishPreviewCard
        case .recentMemory:
            recentMemoryPreviewCard
        case .whisper:
            whisperPreviewCard
        }
    }

    var anniversaryPreviewCard: some View {
        NavigationLink {
            AnniversaryManagementView()
        } label: {
            AppFeatureCard(
                title: "纪念日",
                symbol: "calendar.badge.clock",
                accent: AppTheme.Colors.softAccent
            ) {
                if nextAnniversary == nil {
                    PageActionPill(
                        text: anniversaries.isEmpty ? "去添加" : "查看",
                        systemImage: anniversaries.isEmpty ? "plus" : "calendar"
                    )
                } else {
                    PageActionPill(text: "查看")
                }
            } content: {
                if let nextAnniversary {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(nextAnniversary.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.title)

                                Text(nextAnniversary.shortDateText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Colors.deepAccent)

                                Text(nextAnniversary.note)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.subtitle)
                                    .lineLimit(3)
                                    .lineSpacing(4)
                            }

                            Spacer(minLength: 0)

                            anniversaryCountdownView(for: nextAnniversary)
                        }

                        WrappedPillStack(
                            items: [
                                WrappedPillItem(
                                    text: "里程碑",
                                    systemImage: nextAnniversary.category.symbol
                                ),
                                WrappedPillItem(text: "\(anniversaries.count) 个重要日子")
                            ]
                        )
                    }
                } else if !anniversaries.isEmpty {
                    homeEmptyStateCard(
                        title: "最近没有待提醒的日子",
                        message: "已经留住 \(anniversaries.count) 个重要日子，过去的一次纪念会继续安静留在纪念日页里。",
                        metaItems: [
                            ("已收藏 \(anniversaries.count) 个重要日子", "calendar"),
                            ("点开查看完整时间线", "arrow.up.right")
                        ]
                    )
                } else {
                    homeEmptyStateCard(
                        title: "还没有纪念日",
                        message: "把第一个值得反复想起的日子写下来，首页就会开始认真接住你们的时间感。",
                        metaItems: [
                            ("记录重要日期", "calendar.badge.plus"),
                            ("首页会一直留着入口", "heart")
                        ]
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var wishPreviewCard: some View {
        NavigationLink {
            WishListView()
        } label: {
            AppFeatureCard(
                title: "愿望清单",
                symbol: "paperplane.fill",
                accent: AppTheme.Colors.softAccentSecondary
            ) {
                if featuredWish != nil {
                    progressBadge(value: wishProgressValue)
                } else {
                    PageActionPill(text: "去写下", systemImage: "plus")
                }
            } content: {
                if let featuredWish {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("最近想推进的一件事")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.Colors.deepAccent)

                                Text(featuredWish.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.title)

                                Text(featuredWish.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.subtitle)
                                    .lineLimit(3)
                                    .lineSpacing(4)
                            }

                            AppIconBadge(
                                symbol: featuredWish.symbol,
                                fill: AppTheme.Colors.softAccent.opacity(0.32),
                                size: 42,
                                cornerRadius: 12
                            )
                        }

                        WrappedPillStack(
                            items: [
                                WrappedPillItem(
                                    text: featuredWish.status.rawValue,
                                    systemImage: featuredWish.status.symbol,
                                    emphasis: featuredWish.status != .dreaming
                                ),
                                WrappedPillItem(
                                    text: featuredWish.category.rawValue,
                                    systemImage: featuredWish.category.symbol
                                )
                            ] + (featuredWish.targetText.isEmpty
                                ? []
                                : [WrappedPillItem(text: featuredWish.targetText, systemImage: "clock")])
                        )

                        cardFooter(text: wishFooterText, systemImage: "sparkles")
                    }
                } else {
                    homeEmptyStateCard(
                        title: "还没有共同愿望",
                        message: "先写下一件想一起实现的小事，生活页和首页都会开始帮你们把期待接住。",
                        metaItems: [
                            ("慢慢累积期待", "paperplane.fill"),
                            ("不会变成计划表", "sparkles")
                        ]
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var recentMemoryPreviewCard: some View {
        Button {
            navigationState.selectedTab = .memory
        } label: {
            AppFeatureCard(
                title: "最近记录",
                symbol: "heart.text.square",
                accent: AppTheme.Colors.softAccentSecondary
            ) {
                if latestMemory == nil {
                    PageActionPill(text: "写一条", systemImage: "square.and.pencil")
                } else {
                    PageActionPill(text: "翻一翻")
                }
            } content: {
                if let latestMemory {
                    HomeMemoryPreviewCard(memory: latestMemory)
                } else {
                    homeEmptyStateCard(
                        title: "还没有生活记录",
                        message: "从今天的一小段真实片段开始写，首页会先替你们把最近的生活留在这里。",
                        metaItems: [
                            ("标题 + 正文", "text.alignleft"),
                            ("记忆页同步承接", "heart.text.square")
                        ]
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var whisperPreviewCard: some View {
        AppFeatureCard(
            title: "悄悄话",
            symbol: "envelope.badge",
            accent: AppTheme.Colors.glow
        ) {
            HStack(spacing: 8) {
                if !whisperNotes.isEmpty {
                    Button {
                        isPresentingWhisperList = true
                    } label: {
                        PageActionPill(text: "查看全部", systemImage: "rectangle.stack")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isPresentingWhisperComposer = true
                } label: {
                    PageActionPill(text: "留一张", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    whisperNotes.isEmpty
                    ? "留给对方的一句小纸条"
                    : "最近收好的小纸条"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)

                if whisperPreviewItems.isEmpty {
                    whisperEmptyStateCard
                } else {
                    VStack(spacing: 10) {
                        ForEach(whisperPreviewItems) { item in
                            WhisperPreviewSlip(
                                content: item.previewText,
                                authorText: whisperAuthorText(for: item),
                                timestampText: whisperTimestampText(for: item.createdAt),
                                onEdit: {
                                    editingWhisperItem = item
                                },
                                onDelete: {
                                    pendingDeleteWhisperItem = item
                                }
                            )
                        }
                    }

                    WrappedPillStack(
                        items: [
                            WrappedPillItem(text: "\(whisperNotes.count) 张小纸条", systemImage: "envelope.fill"),
                            WrappedPillItem(text: "只保存在当前空间", systemImage: "lock.fill")
                        ]
                    )
                }
            }
        }
    }

    var whisperEmptyStateCard: some View {
        homeEmptyStateCard(
            title: "还没有悄悄话",
            message: "留一句不太好当面说的话给\(relationshipStore.state.partnerDisplayName)，它会先像被认真收好的小纸条一样待在这里。",
            metaItems: [
                ("只写正文", "text.quote"),
                ("不会变成聊天页", "heart")
            ]
        )
    }

    func homeEmptyStateCard(
        title: String,
        message: String,
        metaItems: [(text: String, systemImage: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            WrappedPillStack(
                items: metaItems.map { WrappedPillItem(text: $0.text, systemImage: $0.systemImage) }
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    var pageBackground: some View {
        AppAtmosphereBackground(
            primaryGlow: AppTheme.Colors.glow.opacity(0.28),
            secondaryGlow: AppTheme.Colors.softAccent.opacity(0.24),
            primaryOffset: CGSize(width: -120, height: -260),
            secondaryOffset: CGSize(width: 120, height: -60)
        )
    }

    var nextAnniversary: AnniversaryItem? {
        anniversaries.first(where: \.hasUpcomingReminder)
    }

    var myStatus: CurrentStatusItem? {
        currentStatusStore.status(for: relationshipStore.state.currentUser.userId, in: contentScope)
    }

    var partnerStatus: CurrentStatusItem? {
        guard let partnerUserID = relationshipStore.state.partner?.userId else { return nil }
        return currentStatusStore.status(for: partnerUserID, in: contentScope)
    }

    var relationshipAnniversary: AnniversaryItem? {
        anniversaries.first(where: { $0.category == .together })
    }

    var featuredWish: PlaceWish? {
        wishes.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.title < rhs.title
            }

            return lhs.status.sortOrder < rhs.status.sortOrder
        }.first
    }

    var completedWishCount: Int {
        wishes.filter { $0.status == .completed }.count
    }

    var wishProgressValue: Double {
        guard !wishes.isEmpty else { return 0 }
        return Double(completedWishCount) / Double(wishes.count)
    }

    var latestMemory: MemoryTimelineEntry? {
        memories.first
    }

    var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    var memories: [MemoryTimelineEntry] {
        memoryStore.entries(in: contentScope)
    }

    var wishes: [PlaceWish] {
        wishStore.wishes(in: contentScope)
    }

    var anniversaries: [AnniversaryItem] {
        anniversaryStore.anniversaries(in: contentScope)
    }

    var weeklyTodoItems: [WeeklyTodoItem] {
        weeklyTodoStore.items(in: contentScope)
    }

    var whisperNotes: [WhisperNoteItem] {
        whisperNoteStore.items(in: contentScope)
    }

    var whisperPreviewItems: [WhisperNoteItem] {
        Array(whisperNotes.prefix(3))
    }

    var whisperDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteWhisperItem != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteWhisperItem = nil
                }
            }
        )
    }

    var pendingWeeklyTodos: [WeeklyTodoItem] {
        weeklyTodoItems.filter { !$0.isCompleted }
    }

    var completedWeeklyTodos: [WeeklyTodoItem] {
        weeklyTodoItems.filter(\.isCompleted)
    }

    var homeCouple: HomeCouple {
        let currentUser = relationshipStore.state.currentUser
        let partner = relationshipStore.state.partner ?? RelationshipUser(
            userId: "partner-placeholder",
            nickname: relationshipStore.state.partnerDisplayName,
            initials: String(relationshipStore.state.partnerDisplayName.prefix(1)).uppercased()
        )

        return HomeCouple(
            first: HomePartner(name: currentUser.nickname, initials: currentUser.initials),
            second: HomePartner(name: partner.nickname, initials: partner.initials),
            sinceText: relationshipStartText,
            relationshipDays: relationshipDayCount,
            note: heroNote
        )
    }

    var currentUserDailyStatus: DailyStatus? {
        myStatus.map {
            DailyStatus(
                personName: relationshipStore.state.currentUser.nickname,
                mood: $0.displayText,
                tone: $0.tone
            )
        }
    }

    var partnerDailyStatus: DailyStatus? {
        partnerStatus.map {
            DailyStatus(
                personName: relationshipStore.state.partnerDisplayName,
                mood: $0.displayText,
                tone: $0.tone
            )
        }
    }

    var heroSharedStatus: HomeSharedStatus {
        let summary: String

        switch (myStatus, partnerStatus) {
        case let (myStatus?, partnerStatus?):
            summary = "你现在是“\(myStatus.displayText)”，\(relationshipStore.state.partnerDisplayName) 是“\(partnerStatus.displayText)”。"
        case let (myStatus?, nil):
            summary = "你现在是“\(myStatus.displayText)”。等对方也写一句状态，这里就会更像一起过日子。"
        case let (nil, partnerStatus?):
            summary = "\(relationshipStore.state.partnerDisplayName) 现在是“\(partnerStatus.displayText)”。你也可以顺手留一句今天的状态。"
        case (nil, nil):
            summary = "把今天、今晚或这周的状态轻轻留一句，首页会先替你们接住此刻的生活感。"
        }

        return HomeSharedStatus(
            summary: summary,
            updatedText: sharedStatusUpdatedText,
            tone: myStatus?.tone ?? partnerStatus?.tone ?? .softGreen
        )
    }

    var relationshipDayCount: Int {
        guard let relationshipStartDate else { return 0 }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: relationshipStartDate)
        let today = calendar.startOfDay(for: .now)
        return max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0)
    }

    var heroNote: String {
        switch (myStatus, partnerStatus) {
        case (_?, _?):
            return "今天你们都留了状态，首页会先替你们记住这点正在发生的生活感。"
        case (_?, nil):
            return "你已经留下一句近况，等对方也写一句时，这里会更像真正一起生活的空间。"
        case (nil, _?):
            return "对方已经留了近况；你也可以写一句，让首页更像两个人正在一起过日子。"
        case (nil, nil):
            return "今天的状态不用写得很复杂，只要一句真实的近况，首页就会安静地接住。"
        }
    }

    var sharedStatusUpdatedText: String {
        guard let latestStatus = [myStatus, partnerStatus]
            .compactMap({ $0 })
            .max(by: { $0.updatedAt < $1.updatedAt }) else {
            return "还没有新的状态"
        }

        return "\(latestStatus.effectiveScope.label) · \(relativeUpdateText(for: latestStatus.updatedAt))"
    }

    var wishFooterText: String {
        if completedWishCount > 0 {
            return "已经一起完成 \(completedWishCount) 个愿望，新的期待也在慢慢靠近"
        }

        return "先把想一起做的事收好，期待会一点点变得更具体"
    }

    var relationshipStartDate: Date? {
        relationshipAnniversary?.date
        ?? relationshipStore.state.pairedAt
        ?? relationshipStore.state.space?.createdAt
    }

    var relationshipStartText: String {
        guard let relationshipStartDate else {
            return "还没有写下关系起点"
        }

        return Self.heroSinceFormatter.string(from: relationshipStartDate)
    }

    var heroMilestoneText: String {
        if let nextAnniversary {
            switch nextAnniversary.reminderState {
            case .today:
                return "\(nextAnniversary.title) 就在今天"
            case let .upcoming(days):
                return "\(nextAnniversary.title) 还有 \(days) 天"
            case .past:
                break
            }
        }

        if !anniversaries.isEmpty {
            return "最近没有待提醒的日子，之前记住的重要时刻还留在纪念日里"
        }

        if let relationshipStartDate {
            return "从 \(Self.heroSinceFormatter.string(from: relationshipStartDate)) 开始把日子慢慢记下来"
        }

        return "写下第一个纪念日，首页就会开始记住时间感"
    }

    func relativeUpdateText(for date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        switch interval {
        case ..<60:
            return "刚刚更新"
        case ..<3600:
            return "\(max(interval / 60, 1)) 分钟前更新"
        case ..<86_400:
            return "\(max(interval / 3600, 1)) 小时前更新"
        default:
            return Self.updateFormatter.string(from: date)
        }
    }

    func whisperAuthorText(for item: WhisperNoteItem) -> String {
        if item.createdByUserId == relationshipStore.state.currentUser.userId {
            return relationshipStore.state.isBound
                ? "你留给 \(relationshipStore.state.partnerDisplayName)"
                : "你留在这个空间里"
        }

        if item.createdByUserId == relationshipStore.state.partner?.userId {
            return "\(relationshipStore.state.partnerDisplayName) 留给你"
        }

        return "留在这个空间里"
    }

    func whisperTimestampText(for date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        switch interval {
        case ..<60:
            return "刚刚写下"
        case ..<3600:
            return "\(max(interval / 60, 1)) 分钟前写下"
        case ..<86_400:
            return "\(max(interval / 3600, 1)) 小时前写下"
        default:
            return Self.whisperFormatter.string(from: date)
        }
    }

    func anniversaryCountdownView(for item: AnniversaryItem) -> some View {
        VStack(spacing: 3) {
            switch item.reminderState {
            case .today:
                Text("今天")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.title)

                Text("提醒")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
            case let .upcoming(days):
                Text("\(days)")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.title)

                Text("天后")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
            case .past:
                Text("已过去")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.title)

                Text("保留")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
            }
        }
        .frame(width: 68)
        .padding(.vertical, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.Colors.divider.opacity(0.9))
                .frame(width: 1, height: 52)
                .offset(x: -10)
        }
    }

    func progressBadge(value: Double) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("\(Int(value * 100))%")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("已完成")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func cardFooter(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(text)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(AppTheme.Colors.deepAccent)
    }

    var spaceSummaryHeadline: String {
        if !pendingWeeklyTodos.isEmpty, let latestMemory {
            return "这周还有 \(pendingWeeklyTodos.count) 件想一起记得的小事，最近也把「\(latestMemory.title)」认真留了下来。"
        }

        if latestMemory != nil {
            return "最近又留下了一段新的生活记录，\(relationshipStore.state.spaceDisplayTitle) 正在慢慢住出自己的样子。"
        }

        if !pendingWeeklyTodos.isEmpty {
            return "这周已经写下了 \(pendingWeeklyTodos.count) 件想一起记得的小事，空间里开始有很具体的生活节奏。"
        }

        if let nextAnniversary {
            switch nextAnniversary.reminderState {
            case .today:
                return "\(nextAnniversary.title) 就在今天，最近的期待也刚好走到了眼前。"
            case let .upcoming(days):
                return "离 \(nextAnniversary.title) 还有 \(days) 天，最近的期待也在慢慢靠近。"
            case .past:
                break
            }
        }

        return "这个双人空间已经把关系、状态和想记住的小事安静接住了，接下来只差继续往里面认真生活。"
    }

    var spaceSummaryBody: String {
        switch (myStatus, partnerStatus) {
        case let (myStatus?, partnerStatus?):
            return "现在你是“\(myStatus.displayText)”，\(relationshipStore.state.partnerDisplayName) 是“\(partnerStatus.displayText)”。两个人的近况都已经落进这个共享空间里。"
        case let (myStatus?, nil):
            return "你已经留下了“\(myStatus.displayText)”这句状态；再补一点这周的计划或记录，首页就会更像真正会被反复打开的空间。"
        case let (nil, partnerStatus?):
            return "\(relationshipStore.state.partnerDisplayName) 已经留下“\(partnerStatus.displayText)”，你们最近的节奏开始有了被接住的感觉。"
        case (nil, nil):
            return relationshipStore.state.isBound
                ? "你们已经在同一个共享空间里。写下状态、留一条记录或记一件这周的小事，首页就会更像你们自己的地方。"
                : "现在仍然是本地优先的两人空间，等关系和日常内容继续累起来，这里会越来越像真正一起生活的首页。"
        }
    }

    var spaceSummaryStateValue: String {
        relationshipStore.state.space?.title ?? "双人共享空间"
    }

    var spaceSummaryStateNote: String {
        if relationshipStore.state.isBound {
            return "当前关系状态：\(relationshipStore.state.relationStatus.label) · \(sharedStatusUpdatedText)"
        }

        return "当前关系状态：\(relationshipStore.state.relationStatus.label) · 先把本地空间慢慢住满。"
    }

    var weeklyRhythmValue: String {
        if let nextWeeklyTodo = pendingWeeklyTodos.first {
            return nextWeeklyTodo.title
        }

        if !completedWeeklyTodos.isEmpty {
            return "这周记下来的事都完成了"
        }

        return "还没有写下这周事项"
    }

    var weeklyRhythmNote: String {
        if let nextWeeklyTodo = pendingWeeklyTodos.first {
            return nextWeeklyTodo.subtitleText.isEmpty
                ? "还有 \(pendingWeeklyTodos.count) 件待完成，先从最近这一件开始。"
                : "还有 \(pendingWeeklyTodos.count) 件待完成 · \(nextWeeklyTodo.subtitleText)"
        }

        if !completedWeeklyTodos.isEmpty {
            return "已经完成 \(completedWeeklyTodos.count) 件，这周的节奏被认真记住了。"
        }

        if let nextAnniversary {
            switch nextAnniversary.reminderState {
            case .today:
                return "\(nextAnniversary.title) 就在今天，记得给这一天留一点认真对待的心情。"
            case let .upcoming(days):
                return "\(nextAnniversary.title) 还有 \(days) 天，可以慢慢准备。"
            case .past:
                break
            }
        }

        return "先写下一件这周想一起记得的小事，空间小结就会更有生活感。"
    }

    var latestMomentValue: String {
        if let latestMemory {
            return latestMemory.title
        }

        if let featuredWish {
            return featuredWish.title
        }

        return "最近还没有新的生活片段"
    }

    var latestMomentNote: String {
        if let latestMemory {
            return latestMemory.bodyExcerpt
        }

        if let featuredWish {
            return featuredWish.detail
        }

        return "可以从一条状态、一件小事或一段记录开始把空间慢慢写满。"
    }

    var gentleSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("空间小结", systemImage: "moon.stars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.deepAccent)

                Spacer(minLength: 12)

                PageMetaPill(
                    text: relationshipStore.state.relationStatus.label,
                    systemImage: relationshipStore.state.relationStatus.symbol,
                    emphasis: relationshipStore.state.isBound
                )
            }

            Text(spaceSummaryHeadline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)
                .lineSpacing(4)

            Text(spaceSummaryBody)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            VStack(spacing: 10) {
                spaceSummaryLine(
                    title: "空间状态",
                    value: spaceSummaryStateValue,
                    note: spaceSummaryStateNote,
                    symbol: "person.2.fill"
                )
                spaceSummaryLine(
                    title: "这周节奏",
                    value: weeklyRhythmValue,
                    note: weeklyRhythmNote,
                    symbol: "checklist"
                )
                spaceSummaryLine(
                    title: "最近留下",
                    value: latestMomentValue,
                    note: latestMomentNote,
                    symbol: "heart.text.square"
                )
            }

            WrappedPillStack(
                items: [
                    WrappedPillItem(text: "\(anniversaries.count) 个纪念日", systemImage: "calendar.badge.clock"),
                    WrappedPillItem(text: "\(wishes.count) 个愿望", systemImage: "paperplane.fill"),
                    WrappedPillItem(text: "\(memories.count) 段记录", systemImage: "heart.text.square")
                ] + (!weeklyTodoItems.isEmpty
                    ? [WrappedPillItem(text: "\(weeklyTodoItems.count) 条本周事项", systemImage: "checklist")]
                    : [])
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.95),
                    AppTheme.Colors.softAccent.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    func spaceSummaryLine(
        title: String,
        value: String,
        note: String,
        symbol: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppIconBadge(
                symbol: symbol,
                fill: AppTheme.Colors.softAccent.opacity(0.26),
                size: 40,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)
                    .lineLimit(2)

                Text(note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineLimit(2)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    static var updateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日更新"
        return formatter
    }

    static var whisperFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日写下"
        return formatter
    }

    static var heroSinceFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter
    }
}

private struct WhisperPreviewSlip: View {
    let content: String
    let authorText: String
    let timestampText: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text("“\(content)”")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.title)
                    .lineLimit(3)
                    .lineSpacing(4)

                Spacer(minLength: 0)

                WhisperSlipMenu(onEdit: onEdit, onDelete: onDelete)
            }

            WrappedPillStack(
                items: [
                    WrappedPillItem(text: authorText, systemImage: "heart"),
                    WrappedPillItem(text: timestampText, systemImage: "clock")
                ]
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct WhisperSlipMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button("编辑", systemImage: "pencil", action: onEdit)
            Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.subtitle)
                .frame(width: 30, height: 30)
                .background(AppTheme.Colors.cardSurface(.tertiary))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct WrappedPillItem: Identifiable {
    let id = UUID()
    let text: String
    var systemImage: String? = nil
    var emphasis: Bool = false
}

struct WrappedPillStack: View {
    let items: [WrappedPillItem]

    private let columns = [
        GridItem(.adaptive(minimum: 128), spacing: AppTheme.Spacing.compact, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.compact) {
            ForEach(items) { item in
                PageMetaPill(
                    text: item.text,
                    systemImage: item.systemImage,
                    emphasis: item.emphasis
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CurrentStatusEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialStatus: CurrentStatusItem?
    let onSave: (String, StatusTone, CurrentStatusEffectiveScope) -> Void
    let onClear: (() -> Void)?

    @State private var displayText: String
    @State private var tone: StatusTone
    @State private var effectiveScope: CurrentStatusEffectiveScope
    @State private var isPresentingClearConfirmation = false

    init(
        initialStatus: CurrentStatusItem?,
        onSave: @escaping (String, StatusTone, CurrentStatusEffectiveScope) -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.initialStatus = initialStatus
        self.onSave = onSave
        self.onClear = onClear
        _displayText = State(initialValue: initialStatus?.displayText ?? "")
        _tone = State(initialValue: initialStatus?.tone ?? .softGreen)
        _effectiveScope = State(initialValue: initialStatus?.effectiveScope ?? .today)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("写一句你现在的近况")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("这里放的是你现在怎么样，不用像发动态那样完整，也不是留给对方的小纸条。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("现在怎么样") {
                    TextField("比如：今天有点忙，但晚上想早点回家", text: $displayText, axis: .vertical)
                        .lineLimit(2...4)

                    Picker("状态语气", selection: $tone) {
                        ForEach(StatusTone.allCases, id: \.self) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("持续范围", selection: $effectiveScope) {
                        ForEach(CurrentStatusEffectiveScope.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                if initialStatus != nil {
                    Section {
                        Button("清空我的近况", role: .destructive) {
                            isPresentingClearConfirmation = true
                        }
                    }
                    .listRowBackground(AppTheme.Colors.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(initialStatus == nil ? "写近况" : "更新近况")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(normalizedDisplayText, tone, effectiveScope)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("清空这句近况？", isPresented: $isPresentingClearConfirmation) {
            Button("清空", role: .destructive) {
                onClear?()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后，首页会回到没有近况的自然状态。")
        }
    }

    private var normalizedDisplayText: String {
        displayText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedDisplayText.isEmpty
    }
}

private struct WhisperComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let partnerName: String
    let existingItem: WhisperNoteItem?
    let onSave: (String) -> Void

    @State private var content: String

    init(
        partnerName: String,
        existingItem: WhisperNoteItem? = nil,
        onSave: @escaping (String) -> Void
    ) {
        self.partnerName = partnerName
        self.existingItem = existingItem
        self.onSave = onSave
        _content = State(initialValue: existingItem?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("留一句见面时不太好说出口的话")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不用写成长文，只留一句想轻轻交给 \(partnerName) 的话。这里更像一张小纸条，不是首页那句现在的近况。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("想留给对方的话") {
                    TextField("比如：其实今天有一点想你，见面时又没好意思说", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(existingItem == nil ? "留一张悄悄话" : "编辑悄悄话")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingItem == nil ? "保存" : "更新") {
                        onSave(normalizedContent)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var normalizedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedContent.isEmpty
    }
}

private struct WhisperListView: View {
    @EnvironmentObject private var whisperNoteStore: WhisperNoteStore
    @EnvironmentObject private var relationshipStore: RelationshipStore

    @State private var isPresentingComposer = false
    @State private var editingItem: WhisperNoteItem?
    @State private var pendingDeleteItem: WhisperNoteItem?

    var body: some View {
        ZStack {
            AppTheme.Colors.pageBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                    AppFeatureCard(
                        title: "收好的悄悄话",
                        subtitle: notes.isEmpty
                            ? "先留下一张小纸条，这里就会开始安静地替你们收着。"
                            : "完整的小纸条都留在这里，首页只保留最近几张预览。",
                        symbol: "envelope.open.fill",
                        accent: AppTheme.Colors.glow
                    ) {
                        Button {
                            isPresentingComposer = true
                        } label: {
                            Text("新增")
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.tint)
                        }
                        .buttonStyle(.plain)
                    } content: {
                        WrappedPillStack(
                            items: [
                                WrappedPillItem(text: "\(notes.count) 张小纸条", systemImage: "envelope.fill"),
                                WrappedPillItem(text: "只保存在当前空间", systemImage: "lock.fill")
                            ]
                        )
                    }

                    if notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("还没有悄悄话")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.title)

                            Text("留一句不太好当面说的话给 \(relationshipStore.state.partnerDisplayName)，它会像被认真收好的小纸条一样待在这里。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.subtitle)
                                .lineSpacing(3)

                            Button {
                                isPresentingComposer = true
                            } label: {
                                PageCTAButton(text: "写下第一张小纸条", systemImage: "square.and.pencil")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Colors.cardSurface(.secondary))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(notes) { item in
                                WhisperPreviewSlip(
                                    content: item.content,
                                    authorText: authorText(for: item),
                                    timestampText: timestampText(for: item.createdAt),
                                    onEdit: {
                                        editingItem = item
                                    },
                                    onDelete: {
                                        pendingDeleteItem = item
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.page)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("悄悄话")
        .secondaryPageNavigationStyle()
        .sheet(isPresented: $isPresentingComposer) {
            WhisperComposerSheet(partnerName: relationshipStore.state.partnerDisplayName) { content in
                whisperNoteStore.add(
                    WhisperNoteItem(content: content),
                    in: contentScope
                )
            }
        }
        .sheet(item: $editingItem) { item in
            WhisperComposerSheet(
                partnerName: relationshipStore.state.partnerDisplayName,
                existingItem: item
            ) { content in
                whisperNoteStore.update(
                    WhisperNoteItem(
                        id: item.id,
                        content: content,
                        createdAt: item.createdAt,
                        createdByUserId: item.createdByUserId,
                        spaceId: item.spaceId,
                        syncStatus: item.syncStatus
                    ),
                    in: contentScope
                )
            }
        }
        .alert(
            "删除这张悄悄话？",
            isPresented: deleteAlertBinding,
            presenting: pendingDeleteItem
        ) { item in
            Button("删除", role: .destructive) {
                whisperNoteStore.delete(item.id, in: contentScope)
                pendingDeleteItem = nil
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("“\(item.previewText)”会从当前空间的小纸条里移除。")
        }
    }

    private var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    private var notes: [WhisperNoteItem] {
        whisperNoteStore.items(in: contentScope)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteItem != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteItem = nil
                }
            }
        )
    }

    private func authorText(for item: WhisperNoteItem) -> String {
        if item.createdByUserId == relationshipStore.state.currentUser.userId {
            return relationshipStore.state.isBound
                ? "你留给 \(relationshipStore.state.partnerDisplayName)"
                : "你留在这个空间里"
        }

        if item.createdByUserId == relationshipStore.state.partner?.userId {
            return "\(relationshipStore.state.partnerDisplayName) 留给你"
        }

        return "留在这个空间里"
    }

    private func timestampText(for date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        switch interval {
        case ..<60:
            return "刚刚写下"
        case ..<3600:
            return "\(max(interval / 60, 1)) 分钟前写下"
        case ..<86_400:
            return "\(max(interval / 3600, 1)) 小时前写下"
        default:
            return Self.whisperFormatter.string(from: date)
        }
    }

    private static var whisperFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日写下"
        return formatter
    }
}
