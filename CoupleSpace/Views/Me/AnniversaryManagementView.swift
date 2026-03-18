import SwiftUI

struct AnniversaryManagementView: View {
    @EnvironmentObject private var anniversaryStore: AnniversaryStore
    @EnvironmentObject private var relationshipStore: RelationshipStore
    @State private var isPresentingAddSheet = false
    @State private var editingAnniversary: AnniversaryItem?
    @State private var recentlyAddedAnniversaryID: UUID?
    @State private var pendingDeleteAnniversary: AnniversaryItem?

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                pageBackground

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                        heroCard

                        PageSectionHeader(
                            title: "时间线索",
                            subtitle: "不是把数字摆出来，而是提醒你们正在一起走过怎样的时间。"
                        )

                        AppFeatureCard(
                            title: "纪念提醒",
                            subtitle: "让重要日子读起来更有节奏一点",
                            symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                            accent: AppTheme.Colors.softAccent
                        ) {
                            if anniversaries.isEmpty {
                                gentleEmptyState(
                                    title: "先留一个重要的日子在这里",
                                    subtitle: "等第一个纪念被写下，这一页就会开始有属于你们的时间纹理。"
                                )
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(timeHighlights) { item in
                                        timelineRow(item: item)
                                    }
                                }
                            }
                        }

                        PageSectionHeader(
                            title: "收藏的重要日子",
                            subtitle: anniversaries.isEmpty
                                ? "现在还是空白，但留白本身也在等一个值得纪念的开始。"
                                : "已经认真留下 \(anniversaries.count) 个重要日子，它们会在合适的时候轻轻提醒你。"
                        )

                        if anniversaries.isEmpty {
                            gentleEmptyState(
                                title: "还没有第一个纪念日",
                                subtitle: "可以从相识、在一起，或者某一次你们都不想忘记的出发开始。"
                            )
                        } else {
                            VStack(spacing: 12) {
                                ForEach(anniversaries) { item in
                                    AnniversaryCardView(
                                        item: item,
                                        isHighlighted: item.id == recentlyAddedAnniversaryID,
                                        onEdit: {
                                            editingAnniversary = item
                                        },
                                        onDelete: {
                                            pendingDeleteAnniversary = item
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
            }
            .navigationTitle("纪念日")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Text("新增")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.tint)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                AddAnniversarySheetView { newAnniversary in
                    withAnimation(.snappy(duration: 0.28)) {
                        anniversaryStore.add(newAnniversary, in: contentScope)
                        recentlyAddedAnniversaryID = newAnniversary.id
                    }
                }
            }
            .sheet(item: $editingAnniversary) { item in
                AddAnniversarySheetView(existingItem: item) { updatedItem in
                    withAnimation(.snappy(duration: 0.28)) {
                        anniversaryStore.update(updatedItem, in: contentScope)
                        recentlyAddedAnniversaryID = updatedItem.id
                    }
                }
            }
            .alert(
                "删除这个纪念日？",
                isPresented: deleteAnniversaryAlertBinding,
                presenting: pendingDeleteAnniversary
            ) { item in
                Button("删除", role: .destructive) {
                    withAnimation(.snappy(duration: 0.24)) {
                        anniversaryStore.delete(item.id, in: contentScope)
                        if recentlyAddedAnniversaryID == item.id {
                            recentlyAddedAnniversaryID = nil
                        }
                    }
                    pendingDeleteAnniversary = nil
                }
                Button("取消", role: .cancel) {}
            } message: { item in
                Text("“\(item.title)”会从当前空间的纪念日里移除。")
            }
            .onChange(of: isPresentingAddSheet) { _, isPresented in
                guard !isPresented, let recentlyAddedAnniversaryID else { return }

                DispatchQueue.main.async {
                    withAnimation(.snappy(duration: 0.3)) {
                        proxy.scrollTo(recentlyAddedAnniversaryID, anchor: .center)
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    guard self.recentlyAddedAnniversaryID == recentlyAddedAnniversaryID else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.recentlyAddedAnniversaryID = nil
                    }
                }
            }
        }
    }

    private var featuredAnniversary: AnniversaryItem? {
        anniversaries.first(where: \.hasUpcomingReminder)
        ?? anniversaries.first(where: { $0.category == .together })
        ?? anniversaries.first
    }

    private var pageBackground: some View {
        AppAtmosphereBackground(
            primaryGlow: AppTheme.Colors.glow.opacity(0.3),
            secondaryGlow: AppTheme.Colors.softAccent.opacity(0.24),
            primaryOffset: CGSize(width: -120, height: -240),
            secondaryOffset: CGSize(width: 120, height: -40)
        )
    }

    private var heroCard: some View {
        Group {
            if let featuredAnniversary {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            PageHeroLabel(text: "重要纪念", systemImage: "calendar.badge.clock")

                            Text(featuredAnniversary.title)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.title)

                            Text(featuredAnniversary.dateText)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.deepAccent)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: featuredAnniversary.category.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.deepAccent.opacity(0.68))
                            .padding(14)
                            .background(AppTheme.Colors.cardSurface(.tertiary))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Text(featuredAnniversary.note.isEmpty ? "把重要日子收好，往后每一次靠近周年，都会更有仪式感。" : featuredAnniversary.note)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)

                    HStack(spacing: 10) {
                        PageStatTile(
                            title: featuredAnniversary.daysSince >= 0 ? "已经走过" : "距离到来",
                            value: "\(abs(featuredAnniversary.daysSince)) 天",
                            minHeight: 82
                        )

                        PageStatTile(
                            title: "下一次提醒",
                            value: featuredReminderTileValue,
                            minHeight: 82
                        )
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))

                        Text(featuredAnniversary.timelineText)
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(AppTheme.Colors.deepAccent)

                    HStack(alignment: .center, spacing: 12) {
                        Button {
                            isPresentingAddSheet = true
                        } label: {
                            PageCTAButton(
                                text: anniversaries.count < 3 ? "再记一个重要日子" : "新增纪念日",
                                systemImage: "plus"
                            )
                        }
                        .buttonStyle(.plain)

                        Text(anniversaries.count < 3
                             ? "把相识、旅行、生日这些时刻慢慢补进去，这页会越来越像你们自己的时间线。"
                             : "不用一次整理很多，只要把下一个舍不得忘的时间点先留住就好。")
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
                            .fill(AppTheme.Colors.glow.opacity(0.48))
                            .frame(width: 200, height: 200)
                            .blur(radius: 32)
                            .offset(x: 120, y: -70)

                        Circle()
                            .fill(AppTheme.Colors.softAccent.opacity(0.32))
                            .frame(width: 160, height: 160)
                            .blur(radius: 24)
                            .offset(x: -100, y: 120)
                    }
                )
                .appCardSurface(
                    AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
                    cornerRadius: AppTheme.CornerRadius.hero,
                    borderColor: AppTheme.Colors.divider
                )
            } else {
                gentleEmptyState(
                    title: "属于你们的第一个重要日子，还在等被写下",
                    subtitle: "不急着列很多，只要先记住一个真正舍不得忘的时间点就很好。"
                )
            }
        }
    }

    private var timeHighlights: [TimeHighlight] {
        guard let featuredAnniversary else { return [] }

        let nearest = anniversaries.first(where: \.hasUpcomingReminder)
        let milestoneValue = featuredAnniversary.daysSince >= 0
            ? "\(featuredAnniversary.daysSince) 天"
            : "\(abs(featuredAnniversary.daysSince)) 天后"

        let nextReminderValue: String
        let nextReminderDetail: String

        if let nearest {
            nextReminderValue = nearest.title
            nextReminderDetail = nearest.nextReminderText
        } else {
            nextReminderValue = "最近没有待提醒的日子"
            nextReminderDetail = "过去的一次性纪念会继续留在时间线里，不再伪装成下一次提醒。"
        }

        return [
            TimeHighlight(
                title: "下一次提醒",
                value: nextReminderValue,
                detail: nextReminderDetail,
                symbol: "bell.badge"
            ),
            TimeHighlight(
                title: "周年节点",
                value: featuredAnniversary.cadence == .yearly ? featuredAnniversary.shortDateText : featuredAnniversary.dateText,
                detail: featuredAnniversary.cadence == .yearly ? "每年这一天都会再被认真想起" : "这是一次只属于当下的节点",
                symbol: "sparkles"
            ),
            TimeHighlight(
                title: "时间线索",
                value: milestoneValue,
                detail: featuredAnniversary.timelineText,
                symbol: "hourglass"
            )
        ]
    }

    private var featuredReminderTileValue: String {
        guard let featuredAnniversary else { return "--" }

        switch featuredAnniversary.reminderState {
        case .today:
            return "今天"
        case let .upcoming(days):
            return "\(days) 天"
        case .past:
            return "已过去"
        }
    }

    private func gentleEmptyState(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            Text("等你们写下第一个重要日子，这里就会慢慢长出属于两个人的时间感。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Button {
                isPresentingAddSheet = true
            } label: {
                PageCTAButton(text: "写下第一个纪念日")
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent)
        )
    }

    private func timelineRow(item: TimeHighlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.softAccent.opacity(0.4))

                Image(systemName: item.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.subtitle)

                Text(item.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)

                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
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
}

private extension AnniversaryManagementView {
    var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    var anniversaries: [AnniversaryItem] {
        anniversaryStore.anniversaries(in: contentScope)
    }

    var deleteAnniversaryAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteAnniversary != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteAnniversary = nil
                }
            }
        )
    }

    struct TimeHighlight: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
        let symbol: String
    }
}
