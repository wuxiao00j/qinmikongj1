import SwiftUI

struct LifeView: View {
    @EnvironmentObject private var weeklyTodoStore: WeeklyTodoStore
    @EnvironmentObject private var tonightDinnerStore: TonightDinnerStore
    @EnvironmentObject private var ritualStore: RitualStore
    @EnvironmentObject private var wishStore: WishStore
    @EnvironmentObject private var pageCardOrderStore: PageCardOrderStore
    @EnvironmentObject private var relationshipStore: RelationshipStore

    @State private var isPresentingAddWeeklyTodoSheet = false
    @State private var isPresentingAddDinnerOptionSheet = false
    @State private var isPresentingAddRitualSheet = false
    @State private var editingWeeklyTodoItem: WeeklyTodoItem?
    @State private var editingDinnerItem: TonightDinnerOption?
    @State private var editingRitualItem: RitualItem?
    @State private var pendingDeleteTarget: LifeDeletionTarget?
    @State private var isPresentingWishList = false
    @State private var isPresentingRitualList = false
    @State private var isPresentingCardOrderEditor = false
    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                        lifeOverviewCard

                        lifeModulesHeader

                        ForEach(pageCardOrderStore.lifeOrder) { cardID in
                            lifeSortableCard(cardID)
                        }
                    }
                    .padding(AppTheme.Spacing.page)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isPresentingWishList) {
                WishListView()
            }
            .navigationDestination(isPresented: $isPresentingRitualList) {
                RitualListView()
            }
            .sheet(isPresented: $isPresentingAddWeeklyTodoSheet) {
                AddWeeklyTodoSheet { newItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        weeklyTodoStore.add(newItem, in: contentScope)
                    }
                }
            }
            .sheet(item: $editingWeeklyTodoItem) { item in
                AddWeeklyTodoSheet(existingItem: item) { updatedItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        weeklyTodoStore.update(updatedItem, in: contentScope)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddDinnerOptionSheet) {
                AddDinnerOptionSheet { newItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        tonightDinnerStore.add(newItem, in: contentScope)
                    }
                }
            }
            .sheet(item: $editingDinnerItem) { item in
                AddDinnerOptionSheet(existingItem: item) { updatedItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        tonightDinnerStore.update(updatedItem, in: contentScope)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddRitualSheet) {
                AddRitualItemSheet { newItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        ritualStore.add(newItem, in: contentScope)
                    }
                }
            }
            .sheet(item: $editingRitualItem) { item in
                AddRitualItemSheet(existingItem: item) { updatedItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        ritualStore.update(updatedItem, in: contentScope)
                    }
                }
            }
            .sheet(isPresented: $isPresentingCardOrderEditor) {
                CardOrderEditorSheet(
                    title: "调整生活页模块顺序",
                    subtitle: "生活总览主卡会保持固定；这里只调整下面这些次级模块卡，让常看的内容更靠前。",
                    items: lifeCardOrderBinding,
                    onReset: {
                        pageCardOrderStore.resetLifeOrder()
                    },
                    titleForItem: \.title,
                    subtitleForItem: \.subtitle,
                    symbolForItem: \.symbol
                )
            }
            .alert(
                "删除这条内容？",
                isPresented: pendingDeleteAlertBinding,
                presenting: pendingDeleteTarget
            ) { target in
                Button("删除", role: .destructive) {
                    performDeletion(for: target)
                }
                Button("取消", role: .cancel) {}
            } message: { target in
                Text(target.message)
            }
        }
    }

    private var lifeCardOrderBinding: Binding<[LifeSortableCardID]> {
        Binding(
            get: { pageCardOrderStore.lifeOrder },
            set: { pageCardOrderStore.setLifeOrder($0) }
        )
    }

    private var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    private var weeklyTodoItems: [WeeklyTodoItem] {
        weeklyTodoStore.items(in: contentScope)
    }

    private var ritualItems: [RitualItem] {
        ritualStore.items(in: contentScope)
    }

    private var tonightDinnerItems: [TonightDinnerOption] {
        tonightDinnerStore.items(in: contentScope)
    }

    private var chosenDinner: TonightDinnerOption? {
        tonightDinnerItems.first(where: { $0.status == .chosen })
    }

    private var dinnerCandidates: [TonightDinnerOption] {
        tonightDinnerItems.filter { $0.status == .candidate }
    }

    private var pendingWeeklyTodos: [WeeklyTodoItem] {
        weeklyTodoItems.filter { !$0.isCompleted }
    }

    private var completedWeeklyTodos: [WeeklyTodoItem] {
        weeklyTodoItems.filter(\.isCompleted)
    }

    private var pendingRitualItems: [RitualItem] {
        ritualItems.filter { !$0.isCompleted }
    }

    private var completedRitualItems: [RitualItem] {
        ritualItems.filter(\.isCompleted)
    }

    private var ritualPreviewItems: [RitualItem] {
        Array(ritualItems.prefix(3))
    }

    private var previewPendingRitualItems: [RitualItem] {
        ritualPreviewItems.filter { !$0.isCompleted }
    }

    private var previewCompletedRitualItems: [RitualItem] {
        ritualPreviewItems.filter(\.isCompleted)
    }

    private var habitRitualCount: Int {
        ritualItems.filter { $0.kind == .habit }.count
    }

    private var promiseRitualCount: Int {
        ritualItems.filter { $0.kind == .promise }.count
    }

    private var nextPendingWeeklyTodo: WeeklyTodoItem? {
        pendingWeeklyTodos.first
    }

    private var wishItems: [PlaceWish] {
        wishStore.wishes(in: contentScope)
    }

    private var previewWishItems: [PlaceWish] {
        Array(wishItems.prefix(3))
    }

    private var openWishCount: Int {
        wishItems.filter { $0.status != .completed }.count
    }

    private var completedWishCount: Int {
        wishItems.filter { $0.status == .completed }.count
    }

    private var dinnerPreviewText: String {
        if let chosenDinner {
            return chosenDinner.title
        }

        let preview = dinnerCandidates.prefix(2).map(\.title).joined(separator: " / ")
        return preview
    }

    private var ritualOverviewTileValue: String {
        ritualItems.isEmpty ? "待写下" : "\(ritualItems.count) 条"
    }

    private var hasSavedDinnerCandidatesFromEarlierDays: Bool {
        guard chosenDinner == nil else { return false }
        let calendar = Calendar.current
        return dinnerCandidates.contains { !calendar.isDate($0.createdAt, inSameDayAs: .now) }
    }

    private var lifeOverviewCard: some View {
        AppFeatureCard(
            title: "两个人的日常",
            symbol: "leaf.fill",
            accent: AppTheme.Colors.softAccentSecondary
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    PageStatTile(title: "小默契", value: ritualOverviewTileValue)
                    PageStatTile(title: "待完成", value: "\(pendingWeeklyTodos.count) 件")
                    PageStatTile(title: "愿望清单", value: "\(openWishCount) 个")
                }

                VStack(spacing: 10) {
                    lifeOverviewHighlight(
                        title: "今晚的节奏",
                        value: dinnerPreviewText.isEmpty ? "还没决定" : dinnerPreviewText,
                        note: nil
                    )

                    lifeOverviewHighlight(
                        title: "这周记得",
                        value: weeklyTodoOverviewValue,
                        note: weeklyTodoOverviewNote
                    )
                }

                HStack(spacing: AppTheme.Spacing.compact) {
                    PageMetaPill(text: "\(weeklyTodoItems.count) 条本周事项", systemImage: "checklist")
                    PageMetaPill(text: "\(wishItems.count) 个愿望", systemImage: "paperplane.fill")
                    if !ritualItems.isEmpty {
                        PageMetaPill(
                            text: completedRitualItems.isEmpty
                                ? "\(ritualItems.count) 条小默契"
                                : "今天做到 \(completedRitualItems.count) 条默契",
                            systemImage: "heart",
                            emphasis: !completedRitualItems.isEmpty
                        )
                    } else if completedWeeklyTodos.count > 0 {
                        PageMetaPill(
                            text: "已完成 \(completedWeeklyTodos.count) 条",
                            systemImage: "checkmark.circle",
                            emphasis: true
                        )
                    } else if completedWishCount > 0 {
                        PageMetaPill(text: "已实现 \(completedWishCount) 个", systemImage: "checkmark.circle", emphasis: true)
                    } else {
                        PageMetaPill(text: "慢慢写下一条小默契", systemImage: "heart")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Button {
                            isPresentingAddDinnerOptionSheet = true
                        } label: {
                            PageCTAButton(text: chosenDinner == nil ? "新增候选" : "再加一个候选", systemImage: "fork.knife")
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var lifeModulesHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            PageSectionHeader(
                title: "生活里正在进行",
                subtitle: "把本周事项、晚饭候选、愿望和小默契按你们更常看的顺序摆在下面。"
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
    private func lifeSortableCard(_ cardID: LifeSortableCardID) -> some View {
        switch cardID {
        case .weeklyTodo:
            weeklyTodoSection
        case .dinner:
            dinnerSection
        case .placeWish:
            placeWishSection
        case .ritual:
            ritualSection
        }
    }

    private var dinnerSection: some View {
        AppSectionCard(
            title: "今晚吃什么",
            symbol: "fork.knife"
        ) {
            Button {
                isPresentingAddDinnerOptionSheet = true
            } label: {
                PageActionPill(text: "新增候选", systemImage: "plus")
            }
            .buttonStyle(.plain)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if let chosenDinner {
                    ChosenDinnerCard(
                        item: chosenDinner,
                        partnerName: relationshipStore.state.partnerDisplayName,
                        onEdit: {
                            editingDinnerItem = chosenDinner
                        },
                        onDelete: {
                            pendingDeleteTarget = .dinner(chosenDinner)
                        }
                    )
                }

                if tonightDinnerItems.isEmpty {
                    dinnerEmptyStateCard
                } else if dinnerCandidates.isEmpty {
                    dinnerSettledStateCard
                } else {
                    dinnerCandidateGroupCard(items: dinnerCandidates)
                }
            }
        }
    }

    private var placeWishSection: some View {
        AppSectionCard(
            title: "愿望清单",
            symbol: "paperplane.fill"
        ) {
            VStack(spacing: 12) {
                if previewWishItems.isEmpty {
                    placeWishEmptyStateCard
                } else {
                    ForEach(previewWishItems) { place in
                        PlaceWishCard(item: place)
                    }
                }
            }

            Button {
                isPresentingWishList = true
            } label: {
                moduleAction(title: "查看愿望清单", systemImage: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private var placeWishEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这里还没有新的愿望")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("先把一个想一起实现的小期待放进来，生活页就会更像两个人正在慢慢靠近的日常。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)

            Button {
                isPresentingWishList = true
            } label: {
                PageCTAButton(text: "去写下第一个愿望", systemImage: "paperplane.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private var ritualSection: some View {
        AppSectionCard(
            title: "小约定",
            symbol: "heart"
        ) {
            HStack(spacing: 8) {
                if !ritualItems.isEmpty {
                    Button {
                        isPresentingRitualList = true
                    } label: {
                        PageActionPill(text: "查看全部", systemImage: "rectangle.stack")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isPresentingAddRitualSheet = true
                } label: {
                    PageActionPill(text: "新增默契", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if ritualItems.isEmpty {
                    ritualEmptyStateCard
                } else {
                    if !previewPendingRitualItems.isEmpty {
                        ritualGroupCard(
                            title: "还想守住的默契",
                            items: previewPendingRitualItems
                        )
                    }

                    if !previewCompletedRitualItems.isEmpty {
                        ritualGroupCard(
                            title: "今天已经做到啦",
                            items: previewCompletedRitualItems
                        )
                    }

                    if ritualItems.count > ritualPreviewItems.count {
                        Button {
                            isPresentingRitualList = true
                        } label: {
                            PageActionPill(text: "查看完整的小默契列表", systemImage: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var weeklyTodoOverviewValue: String {
        if let nextPendingWeeklyTodo {
            return nextPendingWeeklyTodo.subtitleText.isEmpty
                ? nextPendingWeeklyTodo.title
                : "\(nextPendingWeeklyTodo.title) · \(nextPendingWeeklyTodo.subtitleText)"
        }

        return "慢慢补上一件这周想一起记得的小事"
    }

    private var weeklyTodoOverviewNote: String {
        if nextPendingWeeklyTodo != nil {
            let completionText = completedWeeklyTodos.isEmpty
                ? "先从最近这一件开始。"
                : "已经完成 \(completedWeeklyTodos.count) 条。"
            return "还有 \(pendingWeeklyTodos.count) 条待完成，\(completionText)"
        }

        if !weeklyTodoItems.isEmpty {
            return "这周写下来的事都完成了，可以再补一件新的期待。"
        }

        return "先写下一件这周想一起记得的小事，生活页就会更像真正会被打开的地方。"
    }

    private var dinnerEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今晚还没有晚饭候选")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("先写一个想吃的选项留在这里，晚上就不用从空白开始想。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)

            Button {
                isPresentingAddDinnerOptionSheet = true
            } label: {
                PageCTAButton(text: "写下第一个候选", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private var dinnerSettledStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今晚的决定已经收好了")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private func dinnerCandidateGroupCard(items: [TonightDinnerOption]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今晚候选")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    if hasSavedDinnerCandidatesFromEarlierDays {
                        Text("前面留过的候选会继续放在这里，今晚想吃哪个再定下来就好。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                }

                Spacer(minLength: 12)

                PageMetaPill(text: "\(items.count) 个")
            }

            VStack(spacing: 10) {
                ForEach(items) { item in
                    DinnerSuggestionCard(
                        item: item,
                        onChoose: {
                            withAnimation(.snappy(duration: 0.24)) {
                                tonightDinnerStore.choose(item.id, in: contentScope)
                            }
                        },
                        onEdit: {
                            editingDinnerItem = item
                        },
                        onDelete: {
                            pendingDeleteTarget = .dinner(item)
                        }
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private var weeklyTodoSection: some View {
        AppSectionCard(
            title: "本周事项",
            symbol: "checklist"
        ) {
            Button {
                isPresentingAddWeeklyTodoSheet = true
            } label: {
                PageActionPill(text: "新增事项", systemImage: "plus")
            }
            .buttonStyle(.plain)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if weeklyTodoItems.isEmpty {
                    weeklyTodoEmptyStateCard
                } else {
                    if !pendingWeeklyTodos.isEmpty {
                        weeklyTodoGroupCard(
                            title: "这周要做",
                            items: pendingWeeklyTodos
                        )
                    }

                    if !completedWeeklyTodos.isEmpty {
                        weeklyTodoGroupCard(
                            title: "这周做完了",
                            items: completedWeeklyTodos
                        )
                    }
                }
            }
        }
    }

    private var weeklyTodoEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这周还没有要记得的事")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("先留一件想一起记得的事，生活页就会更像真正会被打开的地方。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)

            Button {
                isPresentingAddWeeklyTodoSheet = true
            } label: {
                PageCTAButton(text: "写下第一条事项", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private var ritualEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这里还没有你们的小默契")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("可以是一句睡前晚安，也可以是一点只属于你们的小约定。先写下来，关系感就会更落在日常里。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)

            Button {
                isPresentingAddRitualSheet = true
            } label: {
                PageCTAButton(text: "写下第一条小默契", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private func weeklyTodoGroupCard(
        title: String,
        items: [WeeklyTodoItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                }

                Spacer(minLength: 12)

                PageMetaPill(text: "\(items.count) 条")
            }

            VStack(spacing: 10) {
                ForEach(items) { item in
                    WeeklyTodoRow(item: item) {
                        withAnimation(.snappy(duration: 0.24)) {
                            weeklyTodoStore.setCompletion(
                                !item.isCompleted,
                                for: item.id,
                                in: contentScope
                            )
                        }
                    } onEdit: {
                        editingWeeklyTodoItem = item
                    } onDelete: {
                        pendingDeleteTarget = .weeklyTodo(item)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private func ritualGroupCard(
        title: String,
        items: [RitualItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                }

                Spacer(minLength: 12)

                PageMetaPill(text: "\(items.count) 条")
            }

            HStack(spacing: AppTheme.Spacing.compact) {
                if habitRitualCount > 0 {
                    PageMetaPill(text: "\(habitRitualCount) 个小习惯", systemImage: RitualKind.habit.symbol)
                }
                if promiseRitualCount > 0 {
                    PageMetaPill(text: "\(promiseRitualCount) 个小约定", systemImage: RitualKind.promise.symbol)
                }
            }

            VStack(spacing: 10) {
                ForEach(items) { item in
                    RitualCard(item: item) {
                        withAnimation(.snappy(duration: 0.24)) {
                            ritualStore.setCompletion(
                                !item.isCompleted,
                                for: item.id,
                                in: contentScope
                            )
                        }
                    } onEdit: {
                        editingRitualItem = item
                    } onDelete: {
                        pendingDeleteTarget = .ritual(item)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private func lifeOverviewHighlight(title: String, value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            if let note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
    }

    private var pendingDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteTarget != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteTarget = nil
                }
            }
        )
    }

    private func performDeletion(for target: LifeDeletionTarget) {
        withAnimation(.snappy(duration: 0.24)) {
            switch target {
            case let .weeklyTodo(item):
                weeklyTodoStore.delete(item.id, in: contentScope)
            case let .dinner(item):
                tonightDinnerStore.delete(item.id, in: contentScope)
            case let .ritual(item):
                ritualStore.delete(item.id, in: contentScope)
            }
        }
        pendingDeleteTarget = nil
    }

    private func moduleAction(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))

            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Colors.tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var pageBackground: some View {
        ZStack(alignment: .top) {
            AppAtmosphereBackground(
                primaryGlow: AppTheme.Colors.softAccentSecondary.opacity(0.3),
                secondaryGlow: AppTheme.Colors.glow.opacity(0.24),
                primaryOffset: CGSize(width: -150, height: -270),
                secondaryOffset: CGSize(width: 150, height: -25)
            )

            topAtmosphere
        }
    }

    private var topAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.softAccentSecondary.opacity(0.2),
                    AppTheme.Colors.softAccent.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
            .blur(radius: 8)
            .offset(y: -24)

            Circle()
                .fill(AppTheme.Colors.softAccentSecondary.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 44)
                .offset(x: -110, y: -72)

            Circle()
                .fill(AppTheme.Colors.glow.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 118, y: -22)
        }
        .allowsHitTesting(false)
    }
}

private struct RitualListView: View {
    @EnvironmentObject private var ritualStore: RitualStore
    @EnvironmentObject private var relationshipStore: RelationshipStore

    @State private var isPresentingAddSheet = false
    @State private var editingItem: RitualItem?
    @State private var pendingDeleteItem: RitualItem?

    var body: some View {
        ZStack {
            AppTheme.Colors.pageBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                    AppFeatureCard(
                        title: "小约定",
                        subtitle: items.isEmpty
                            ? "先留下一条只属于你们的小默契，这里就会开始替你们完整收好。"
                            : "完整的小默契列表留在这里，生活页只先放最关键的几条。",
                        symbol: "heart.fill",
                        accent: AppTheme.Colors.softAccent
                    ) {
                        Button {
                            isPresentingAddSheet = true
                        } label: {
                            Text("新增")
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.tint)
                        }
                        .buttonStyle(.plain)
                    } content: {
                        WrappedPillStack(
                            items: [
                                WrappedPillItem(text: "\(items.count) 条小默契", systemImage: "heart.fill")
                            ] + (habitCount > 0
                                ? [WrappedPillItem(text: "\(habitCount) 个小习惯", systemImage: RitualKind.habit.symbol)]
                                : []) + (promiseCount > 0
                                    ? [WrappedPillItem(text: "\(promiseCount) 个小约定", systemImage: RitualKind.promise.symbol)]
                                    : [])
                        )
                    }

                    if items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("这里还没有你们的小默契")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.title)

                            Text("可以是一句睡前晚安，也可以是一点只属于你们的小约定。先写下来，关系感就会更落在日常里。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.subtitle)
                                .lineSpacing(3)

                            Button {
                                isPresentingAddSheet = true
                            } label: {
                                PageCTAButton(text: "写下第一条小默契", systemImage: "plus")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCardSurface(
                            AppTheme.Colors.cardSurface(.secondary),
                            cornerRadius: AppTheme.CornerRadius.medium
                        )
                    } else {
                        if !pendingItems.isEmpty {
                            ritualGroupCard(
                                title: "还想守住的默契",
                                subtitle: "不是打卡，只是把想一起慢慢做到的小默契放在眼前。",
                                items: pendingItems
                            )
                        }

                        if !completedItems.isEmpty {
                            ritualGroupCard(
                                title: "今天已经做到啦",
                                subtitle: "做到了也先留着，能看见今天已经守住了哪些轻轻的小约定。",
                                items: completedItems
                            )
                        }
                    }
                }
                .padding(AppTheme.Spacing.page)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("小约定")
        .secondaryPageNavigationStyle()
        .sheet(isPresented: $isPresentingAddSheet) {
            AddRitualItemSheet { newItem in
                withAnimation(.snappy(duration: 0.28)) {
                    ritualStore.add(newItem, in: contentScope)
                }
            }
        }
        .sheet(item: $editingItem) { item in
            AddRitualItemSheet(existingItem: item) { updatedItem in
                withAnimation(.snappy(duration: 0.28)) {
                    ritualStore.update(updatedItem, in: contentScope)
                }
            }
        }
        .alert(
            "删除这条内容？",
            isPresented: deleteAlertBinding,
            presenting: pendingDeleteItem
        ) { item in
            Button("删除", role: .destructive) {
                withAnimation(.snappy(duration: 0.24)) {
                    ritualStore.delete(item.id, in: contentScope)
                }
                pendingDeleteItem = nil
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("“\(item.title)”会从这页的小默契里移除。")
        }
    }

    private var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    private var items: [RitualItem] {
        ritualStore.items(in: contentScope)
    }

    private var pendingItems: [RitualItem] {
        items.filter { !$0.isCompleted }
    }

    private var completedItems: [RitualItem] {
        items.filter(\.isCompleted)
    }

    private var habitCount: Int {
        items.filter { $0.kind == .habit }.count
    }

    private var promiseCount: Int {
        items.filter { $0.kind == .promise }.count
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

    private func ritualGroupCard(
        title: String,
        subtitle: String,
        items: [RitualItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }

                Spacer(minLength: 12)

                PageMetaPill(text: "\(items.count) 条")
            }

            HStack(spacing: AppTheme.Spacing.compact) {
                if habitCount > 0 {
                    PageMetaPill(text: "\(habitCount) 个小习惯", systemImage: RitualKind.habit.symbol)
                }
                if promiseCount > 0 {
                    PageMetaPill(text: "\(promiseCount) 个小约定", systemImage: RitualKind.promise.symbol)
                }
            }

            VStack(spacing: 10) {
                ForEach(items) { item in
                    RitualCard(item: item) {
                        withAnimation(.snappy(duration: 0.24)) {
                            ritualStore.setCompletion(
                                !item.isCompleted,
                                for: item.id,
                                in: contentScope
                            )
                        }
                    } onEdit: {
                        editingItem = item
                    } onDelete: {
                        pendingDeleteItem = item
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}

private struct WeeklyTodoRow: View {
    let item: WeeklyTodoItem
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(item.isCompleted ? AppTheme.Colors.deepAccent : AppTheme.Colors.subtitle)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)
                    .strikethrough(item.isCompleted)

                if !item.subtitleText.isEmpty {
                    HStack(spacing: 6) {
                        if let owner = item.owner {
                            Image(systemName: owner.symbol)
                                .font(.caption.weight(.semibold))
                        }

                        Text(item.subtitleText)
                            .font(.footnote)
                    }
                    .foregroundStyle(AppTheme.Colors.subtitle)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 10) {
                Button(action: onToggleCompletion) {
                    PageActionPill(
                        text: item.isCompleted ? "取消完成" : "完成",
                        systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                }
                .buttonStyle(.plain)

                WeeklyTodoRowMenu(onEdit: onEdit, onDelete: onDelete)

                if item.isCompleted {
                    PageMetaPill(text: "已完成", systemImage: "checkmark")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            item.isCompleted
                ? AppTheme.Colors.cardSurface(.tertiary)
                : AppTheme.Colors.cardSurface(.primary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}

private struct AddWeeklyTodoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingItem: WeeklyTodoItem?
    let onSave: (WeeklyTodoItem) -> Void

    @State private var title: String
    @State private var includesDate: Bool
    @State private var scheduledDate: Date
    @State private var ownerRawValue: String

    init(
        existingItem: WeeklyTodoItem? = nil,
        onSave: @escaping (WeeklyTodoItem) -> Void
    ) {
        self.existingItem = existingItem
        self.onSave = onSave
        let initialDate = existingItem?.scheduledDate ?? Calendar.current.startOfDay(for: .now)
        _title = State(initialValue: existingItem?.title ?? "")
        _includesDate = State(initialValue: existingItem?.scheduledDate != nil)
        _scheduledDate = State(initialValue: initialDate)
        _ownerRawValue = State(initialValue: existingItem?.owner?.rawValue ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("先写下一件这周想一起记得的小事")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不用像任务管理器那样排满，只要留下一件这周不想忘记的事，生活页就会更有抓手。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("事项内容") {
                    TextField("这周想一起记得什么", text: $title)

                    Toggle("补一个日期", isOn: $includesDate)

                    if includesDate {
                        DatePicker("日期", selection: $scheduledDate, displayedComponents: .date)
                    }

                    Picker("由谁来记得", selection: $ownerRawValue) {
                        Text("不用区分").tag("")
                        ForEach(WeeklyTodoOwner.allCases) { owner in
                            Text(owner.label).tag(owner.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .navigationTitle(existingItem == nil ? "新增事项" : "编辑事项")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingItem == nil ? "保存" : "更新") {
                        onSave(
                            WeeklyTodoItem(
                                id: existingItem?.id ?? UUID(),
                                title: normalizedTitle,
                                isCompleted: existingItem?.isCompleted ?? false,
                                scheduledDate: includesDate ? scheduledDate : nil,
                                owner: WeeklyTodoOwner(rawValue: ownerRawValue),
                                spaceId: existingItem?.spaceId ?? AppDataDefaults.localSpaceId,
                                createdByUserId: existingItem?.createdByUserId ?? AppDataDefaults.localUserId,
                                createdAt: existingItem?.createdAt ?? .now,
                                updatedAt: existingItem?.updatedAt,
                                syncStatus: existingItem?.syncStatus ?? .localOnly
                            )
                        )
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

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty
    }
}

private struct WeeklyTodoRowMenu: View {
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

private enum LifeDeletionTarget: Identifiable {
    case weeklyTodo(WeeklyTodoItem)
    case dinner(TonightDinnerOption)
    case ritual(RitualItem)

    var id: String {
        switch self {
        case let .weeklyTodo(item):
            return "weekly-\(item.id.uuidString)"
        case let .dinner(item):
            return "dinner-\(item.id.uuidString)"
        case let .ritual(item):
            return "ritual-\(item.id.uuidString)"
        }
    }

    var message: String {
        switch self {
        case let .weeklyTodo(item):
            return "“\(item.title)”会从当前生活页里移除。"
        case let .dinner(item):
            return item.status == .chosen
                ? "“\(item.title)”会从今晚结果里移除，当前晚饭决定也会一起清空。"
                : "“\(item.title)”会从今晚候选里移除。"
        case let .ritual(item):
            return "“\(item.title)”会从这页的小默契里移除。"
        }
    }
}
