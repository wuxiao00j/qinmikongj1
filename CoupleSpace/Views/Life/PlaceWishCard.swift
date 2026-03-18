import SwiftUI

struct PlaceWishCard: View {
    let item: PlaceWish

    var body: some View {
        HStack(alignment: .cardTitleCenter, spacing: 12) {
            AppIconBadge(
                symbol: item.symbol,
                fill: AppTheme.Colors.softAccent.opacity(0.35),
                size: 42,
                cornerRadius: 12
            )
            .alignmentGuide(.cardTitleCenter) { dimensions in
                dimensions[VerticalAlignment.center]
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)
                    .alignmentGuide(.cardTitleCenter) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            PageMetaPill(text: item.status.rawValue, emphasis: item.status == .completed)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}

struct WishListView: View {
    @EnvironmentObject private var wishStore: WishStore
    @EnvironmentObject private var relationshipStore: RelationshipStore
    @State private var isPresentingAddSheet = false
    @State private var editingWish: PlaceWish?
    @State private var recentlyAddedWishID: UUID?
    @State private var pendingDeleteWish: PlaceWish?

    private var sortedWishes: [PlaceWish] {
        wishes.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.title < rhs.title
            }

            return lhs.status.sortOrder < rhs.status.sortOrder
        }
    }

    private var completedCount: Int {
        wishes.filter { $0.status == .completed }.count
    }

    private var planningCount: Int {
        wishes.filter { $0.status == .planning }.count
    }

    private var progressValue: Double {
        guard !wishes.isEmpty else { return 0 }
        return Double(completedCount) / Double(wishes.count)
    }

    private var categorySummaries: [WishCategorySummary] {
        WishCategory.allCases.compactMap { category in
            let count = wishes.filter { $0.category == category }.count
            guard count > 0 else { return nil }
            return WishCategorySummary(category: category, count: count)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                    heroCard

                    PageSectionHeader(
                        title: "现在的期待",
                        subtitle: "把正在靠近的、已经计划中的、已经完成的都轻轻放在一起。"
                    )

                    AppFeatureCard(
                        title: "状态概览",
                        subtitle: "不用像任务管理器那样精确，只要知道期待正慢慢推进就很好。",
                        symbol: "sparkles",
                        accent: AppTheme.Colors.softAccentSecondary
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                statusCard(status: .dreaming, count: wishes.filter { $0.status == .dreaming }.count)
                                statusCard(status: .planning, count: planningCount)
                                statusCard(status: .completed, count: completedCount)
                            }

                            if !categorySummaries.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(categorySummaries) { summary in
                                            categoryPill(summary: summary)
                                        }
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                        }
                    }

                    PageSectionHeader(
                        title: "共同期待的事情",
                        subtitle: wishes.isEmpty
                            ? "还没有写下来的愿望，也许正藏在你们下一次聊天里。"
                            : "这些愿望不赶进度，它们更像两个人正在慢慢靠近的未来。"
                    )

                    if wishes.isEmpty {
                        emptyStateCard
                    } else {
                        VStack(spacing: 14) {
                            if wishes.count < 4 {
                                addWishPromptCard
                            }

                            ForEach(sortedWishes) { item in
                                WishListItemCard(
                                    item: item,
                                    isHighlighted: item.id == recentlyAddedWishID,
                                    onEdit: {
                                        editingWish = item
                                    },
                                    onDelete: {
                                        pendingDeleteWish = item
                                    }
                                )
                                .id(item.id)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.page)
                .padding(.bottom, 28)
            }
            .onChange(of: isPresentingAddSheet) { _, isPresented in
                guard !isPresented, let recentlyAddedWishID else { return }

                DispatchQueue.main.async {
                    withAnimation(.snappy(duration: 0.3)) {
                        proxy.scrollTo(recentlyAddedWishID, anchor: .center)
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    guard self.recentlyAddedWishID == recentlyAddedWishID else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.recentlyAddedWishID = nil
                    }
                }
            }
        }
        .background(pageBackground)
        .navigationTitle("愿望清单")
        .secondaryPageNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Text("新增愿望")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AddWishSheet { newWish in
                withAnimation(.snappy(duration: 0.28)) {
                    wishStore.add(newWish, in: contentScope)
                    recentlyAddedWishID = newWish.id
                }
            }
        }
        .sheet(item: $editingWish) { wish in
            AddWishSheet(existingWish: wish) { updatedWish in
                withAnimation(.snappy(duration: 0.28)) {
                    wishStore.update(updatedWish, in: contentScope)
                    recentlyAddedWishID = updatedWish.id
                }
            }
        }
        .alert(
            "删除这个愿望？",
            isPresented: deleteWishAlertBinding,
            presenting: pendingDeleteWish
        ) { wish in
            Button("删除", role: .destructive) {
                withAnimation(.snappy(duration: 0.24)) {
                    wishStore.delete(wish.id, in: contentScope)
                }
                pendingDeleteWish = nil
            }
            Button("取消", role: .cancel) {}
        } message: { wish in
            Text("“\(wish.title)”会从当前空间的愿望清单里移除。")
        }
    }

    private var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    private var wishes: [PlaceWish] {
        wishStore.wishes(in: contentScope)
    }

    private var deleteWishAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteWish != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteWish = nil
                }
            }
        )
    }

    private var pageBackground: some View {
        AppAtmosphereBackground(
            primaryGlow: AppTheme.Colors.softAccentSecondary.opacity(0.28),
            secondaryGlow: AppTheme.Colors.glow.opacity(0.2),
            primaryOffset: CGSize(width: -120, height: -235),
            secondaryOffset: CGSize(width: 125, height: -45)
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    PageHeroLabel(text: "两个人的愿望清单", systemImage: "paperplane")

                    Text("把那些想一起完成的事，先轻轻放在这里。")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.title)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("不把它当任务，也不用急着完成。只是先把那些会让人期待的事，好好收在一起。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }

                Spacer(minLength: 12)

                Image(systemName: "star.circle.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent.opacity(0.72))
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                PageStatTile(title: "愿望总数", value: "\(wishes.count)")
                PageStatTile(title: "已完成", value: "\(completedCount)")
                PageStatTile(title: "完成进度", value: "\(Int(progressValue * 100))%")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("慢慢实现中")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.deepAccent)

                    Spacer(minLength: 12)

                    Text("\(planningCount) 个正在靠近")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                }

                ProgressView(value: progressValue)
                    .tint(AppTheme.Colors.deepAccent)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)
            }

            HStack(alignment: .center, spacing: 12) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    PageCTAButton(
                        text: wishes.isEmpty ? "写下第一个愿望" : "新增一个愿望",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.plain)

                Text(wishes.count < 4
                     ? "从一个最近就想一起做的小计划开始，这页会慢慢长出属于两个人的期待感。"
                     : "不用列很多，把下一个想一起完成的念头先放进来就好。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.glow.opacity(0.44))
                    .frame(width: 220, height: 220)
                    .blur(radius: 34)
                    .offset(x: 130, y: -70)

                Circle()
                    .fill(AppTheme.Colors.softAccentSecondary.opacity(0.38))
                    .frame(width: 170, height: 170)
                    .blur(radius: 24)
                    .offset(x: -120, y: 100)
            }
        )
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccentSecondary),
            cornerRadius: AppTheme.CornerRadius.hero,
            borderColor: AppTheme.Colors.divider
        )
    }

    private func statusCard(status: WishStatus, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AppIconBadge(
                symbol: status.symbol,
                fill: AppTheme.Colors.softAccent.opacity(0.32),
                size: 36,
                cornerRadius: 12
            )

            Text("\(count)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(status.rawValue)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.subtitle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }

    private func categoryPill(summary: WishCategorySummary) -> some View {
        HStack(spacing: 8) {
            PageMetaPill(text: summary.category.rawValue, systemImage: summary.category.symbol)

            Text("\(summary.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.deepAccent)
        }
        .padding(.horizontal, 2)
    }

    private var addWishPromptCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("还有新的期待，也可以先放进来")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text("不管是想去的地方、想完成的一件小事，还是一个还没定下来的计划，都值得先被收好。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }

            Spacer(minLength: 12)

            Button {
                isPresentingAddSheet = true
            } label: {
                PageCTAButton(text: "继续添加")
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

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Text("属于你们的第一个愿望，还可以慢一点再写")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("等某个想一起去的地方、想一起完成的小计划，或者一个突然冒出来的念头出现，再把它放进来就好。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            Text("这页会替你们把期待先收好。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Button {
                isPresentingAddSheet = true
            } label: {
                PageCTAButton(text: "写下第一个愿望")
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent)
        )
    }
}

private struct WishListItemCard: View {
    let item: PlaceWish
    var isHighlighted: Bool = false
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .cardTitleCenter, spacing: 12) {
                AppIconBadge(symbol: item.symbol, fill: iconBackground, size: 46, cornerRadius: 15)
                    .alignmentGuide(.cardTitleCenter) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)
                            .alignmentGuide(.cardTitleCenter) { dimensions in
                                dimensions[VerticalAlignment.center]
                            }

                        Spacer(minLength: 8)

                        statusBadge
                        WishItemMenu(onEdit: onEdit, onDelete: onDelete)
                    }

                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }
            }

            HStack(spacing: 8) {
                metaPill(text: item.category.rawValue, systemImage: item.category.symbol)

                if !item.targetText.isEmpty {
                    metaPill(text: item.targetText, systemImage: "clock")
                }
            }

            if !item.note.isEmpty {
                Text(item.note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }

            if item.status != .completed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.status == .planning ? "已经开始靠近" : "先把期待收好")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.deepAccent)

                        Spacer(minLength: 12)

                        Text("\(Int(item.status.progressValue * 100))%")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                    }

                    ProgressView(value: item.status.progressValue)
                        .tint(AppTheme.Colors.deepAccent)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))

                    Text("已经一起完成，但仍然值得反复想起。")
                        .font(.footnote.weight(.medium))
                }
                .foregroundStyle(AppTheme.Colors.deepAccent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(
                .primary,
                accent: item.status == .completed ? AppTheme.Colors.softAccentSecondary : AppTheme.Colors.softAccent
            ),
            cornerRadius: AppTheme.CornerRadius.large,
            borderColor: isHighlighted ? AppTheme.Colors.softAccent : (item.status == .completed ? AppTheme.Colors.softAccent.opacity(0.8) : AppTheme.Colors.cardStroke)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                .stroke(
                    isHighlighted ? AppTheme.Colors.tint.opacity(0.28) : .clear,
                    lineWidth: 1.5
                )
        }
        .shadow(
            color: isHighlighted ? AppTheme.Colors.tint.opacity(0.12) : .clear,
            radius: 14,
            x: 0,
            y: 8
        )
        .overlay(alignment: .topTrailing) {
            if item.status == .completed {
                Text("已实现")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.cardSurface(.tertiary))
                    .clipShape(Capsule())
                    .padding(14)
            }
        }
    }

    private var iconBackground: Color {
        item.status == .completed ? AppTheme.Colors.softAccentSecondary.opacity(0.78) : AppTheme.Colors.softAccent.opacity(0.38)
    }

    private var statusBadge: some View {
        PageMetaPill(text: item.status.rawValue, emphasis: item.status == .completed)
    }

    private func metaPill(text: String, systemImage: String) -> some View {
        PageMetaPill(text: text, systemImage: systemImage)
    }
}

private struct WishItemMenu: View {
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

private struct WishCategorySummary: Identifiable {
    let id = UUID()
    let category: WishCategory
    let count: Int
}

private struct AddWishSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingWish: PlaceWish?
    let onSave: (PlaceWish) -> Void

    @State private var title: String
    @State private var detail: String
    @State private var note: String
    @State private var targetText: String
    @State private var category: WishCategory
    @State private var status: WishStatus

    init(
        existingWish: PlaceWish? = nil,
        onSave: @escaping (PlaceWish) -> Void
    ) {
        self.existingWish = existingWish
        self.onSave = onSave
        _title = State(initialValue: existingWish?.title ?? "")
        _detail = State(initialValue: existingWish?.detail ?? "")
        _note = State(initialValue: existingWish?.note ?? "")
        _targetText = State(initialValue: existingWish?.targetText ?? "")
        _category = State(initialValue: existingWish?.category ?? .date)
        _status = State(initialValue: existingWish?.status ?? .dreaming)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("把一个想一起实现的念头先收好")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("不需要很完整，也不用现在就排进日程。只要你们都想过这件事，就值得先写下来。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("愿望内容") {
                    TextField("标题", text: $title)
                    TextField("一句话描述", text: $detail, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("想在什么时候实现", text: $targetText)
                    TextField("补一句备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                Section("现在的状态") {
                    Picker("愿望类型", selection: $category) {
                        ForEach(WishCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("进展状态", selection: $status) {
                        ForEach(WishStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(existingWish == nil ? "新增愿望" : "编辑愿望")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingWish == nil ? "保存" : "更新") {
                        onSave(
                            PlaceWish(
                                id: existingWish?.id ?? UUID(),
                                title: normalizedTitle,
                                detail: normalizedDetail,
                                note: normalizedNote,
                                category: category,
                                status: status,
                                targetText: normalizedTargetText,
                                symbol: category.symbol,
                                spaceId: existingWish?.spaceId ?? AppDataDefaults.localSpaceId,
                                createdByUserId: existingWish?.createdByUserId ?? AppDataDefaults.localUserId,
                                createdAt: existingWish?.createdAt ?? .now,
                                updatedAt: existingWish?.updatedAt ?? .now,
                                syncStatus: existingWish?.syncStatus ?? .localOnly
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

    private var normalizedDetail: String {
        detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTargetText: String {
        targetText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty && !normalizedDetail.isEmpty
    }
}
