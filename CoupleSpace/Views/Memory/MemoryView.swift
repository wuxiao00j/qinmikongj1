import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var memoryStore: MemoryStore
    @EnvironmentObject private var relationshipStore: RelationshipStore
    @State private var isPresentingAddSheet = false
    @State private var editingEntry: MemoryTimelineEntry?
    @State private var pendingDeleteEntry: MemoryTimelineEntry?
    @State private var scrollTargetID: MemoryTimelineEntry.ID?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    pageBackground

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                            heroCard

                            AppFeatureCard(
                                title: "记录概览",
                                subtitle: "让最近写下来的生活记录，读起来更像一页页真实留下的日常。",
                                symbol: "clock.arrow.circlepath",
                                accent: AppTheme.Colors.softAccent
                            ) {
                                HStack(spacing: 10) {
                                    PageStatTile(
                                        title: "最近更新",
                                        value: latestEntry?.monthDayText ?? "还没写下"
                                    )
                                    PageStatTile(
                                        title: "本月记录",
                                        value: "\(thisMonthCount) 条"
                                    )
                                    PageStatTile(
                                        title: "连续记录",
                                        value: "\(recordingStreak) 天"
                                    )
                                }

                                if let latestEntry {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.caption.weight(.semibold))

                                        Text("最近写下的是“\(latestEntry.title)”，那段正文会继续把当时的空气留在这里。")
                                            .font(.footnote.weight(.medium))
                                    }
                                    .foregroundStyle(AppTheme.Colors.deepAccent)
                                }
                            }

                            if let featuredEntry {
                                PageSectionHeader(
                                    title: "最近想重看的一页",
                                    subtitle: "不是最隆重的一天，而是那种翻出来仍然会觉得很温柔的时刻。"
                                )

                                featuredCard(entry: featuredEntry)
                                    .id(featuredEntry.id)
                            }

                            PageSectionHeader(
                                title: "生活记录",
                                subtitle: entries.isEmpty
                                    ? "第一条生活记录，还在等你们把一个真实片段认真写下来。"
                                    : "这些记录不用写成长文，只要标题和正文都还留着，那天就会被重新想起。"
                            )

                            if listEntries.isEmpty && featuredEntry == nil {
                                emptyStateCard
                            } else {
                                ForEach(groupedEntries) { section in
                                    VStack(alignment: .leading, spacing: 14) {
                                        Text(section.title)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.title)

                                        ForEach(section.entries) { entry in
                                            MemoryTimelineRow(
                                                entry: entry,
                                                showsManagementMenu: canManageEntries,
                                                onEdit: {
                                                    editingEntry = entry
                                                },
                                                onDelete: {
                                                    pendingDeleteEntry = entry
                                                }
                                            )
                                                .id(entry.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.page)
                        .padding(.bottom, 88)
                    }

                    MemoryAddButton {
                        isPresentingAddSheet = true
                    }
                    .padding(.trailing, AppTheme.Spacing.page)
                    .padding(.bottom, 28)
                }
                .sheet(isPresented: $isPresentingAddSheet) {
                    AddMemorySheet { newEntry in
                        withAnimation(.snappy(duration: 0.28)) {
                            memoryStore.add(newEntry, in: contentScope)
                            scrollTargetID = newEntry.id
                        }
                    }
                }
                .sheet(item: $editingEntry) { entry in
                    AddMemorySheet(existingEntry: entry) { updatedEntry in
                        withAnimation(.snappy(duration: 0.28)) {
                            memoryStore.update(updatedEntry, in: contentScope)
                            scrollTargetID = updatedEntry.id
                        }
                    }
                }
                .onChange(of: scrollTargetID) { _, newValue in
                    guard let newValue else { return }
                    DispatchQueue.main.async {
                        withAnimation(.snappy(duration: 0.32)) {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                    }
                }
                .alert(
                    "删除这条记录？",
                    isPresented: memoryDeleteAlertBinding,
                    presenting: pendingDeleteEntry
                ) { entry in
                    Button("删除", role: .destructive) {
                        withAnimation(.snappy(duration: 0.24)) {
                            memoryStore.delete(entry.id, in: contentScope)
                        }
                        pendingDeleteEntry = nil
                    }
                    Button("取消", role: .cancel) {}
                } message: { entry in
                    Text("“\(entry.title)”会从当前空间的生活记录里移除。")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private extension MemoryView {
    var contentScope: AppContentScope {
        relationshipStore.contentScope
    }

    var canManageEntries: Bool {
        memoryStore.hasPersistedEntries
    }

    var entries: [MemoryTimelineEntry] {
        memoryStore.entries(in: contentScope)
    }

    var latestEntry: MemoryTimelineEntry? {
        entries.max(by: { $0.date < $1.date })
    }

    var featuredEntry: MemoryTimelineEntry? {
        entries.first(where: \.isFeatured) ?? entries.first
    }

    var listEntries: [MemoryTimelineEntry] {
        guard let featuredEntry else { return entries }
        return entries.filter { $0.id != featuredEntry.id }
    }

    var thisMonthCount: Int {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }.count
    }

    var recordingStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Array(Set(entries.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)
        guard let first = uniqueDays.first else { return 0 }

        var streak = 1
        var previousDay = first

        for day in uniqueDays.dropFirst() {
            let difference = calendar.dateComponents([.day], from: day, to: previousDay).day ?? 0
            guard difference == 1 else { break }
            streak += 1
            previousDay = day
        }

        return streak
    }

    var groupedEntries: [MemorySection] {
        Dictionary(grouping: listEntries, by: \.yearMonthText)
            .map { key, value in
                MemorySection(
                    title: key,
                    entries: value.sorted { $0.date > $1.date },
                    sortDate: value.map(\.date).max() ?? .distantPast
                )
            }
            .sorted { $0.sortDate > $1.sortDate }
    }

    var memoryDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteEntry != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteEntry = nil
                }
            }
        )
    }

    var pageBackground: some View {
        AppAtmosphereBackground(
            primaryGlow: AppTheme.Colors.glow.opacity(0.24),
            secondaryGlow: AppTheme.Colors.softAccent.opacity(0.22),
            primaryOffset: CGSize(width: -120, height: -235),
            secondaryOffset: CGSize(width: 120, height: -35)
        )
    }

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    PageHeroLabel(text: "生活记录", systemImage: "book.closed.fill")

                    Text("把两个人的生活片段，安静地写成能反复翻开的几页日常。")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.title)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("不用写成长文。只要把标题和正文认真留住，那些过几天还会想起的时刻，就会更像真正被收好了。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }

                Spacer(minLength: 12)

                Image(systemName: "book.pages.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent.opacity(0.72))
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                PageStatTile(title: "记录总数", value: "\(entries.count)")
                PageStatTile(title: "本月记录", value: "\(thisMonthCount)")
                PageStatTile(title: "最近更新", value: latestEntry?.monthDayText ?? "--")
            }

            if let latestEntry {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption.weight(.semibold))

                    Text("最近写下的是“\(latestEntry.title)”，\(latestEntry.recordContextText)。")
                        .font(.footnote.weight(.medium))
                }
                .foregroundStyle(AppTheme.Colors.deepAccent)
            }

            HStack(alignment: .center, spacing: 12) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    PageCTAButton(
                        text: entries.isEmpty ? "写下第一篇记录" : "写下今天的记录",
                        systemImage: "square.and.pencil"
                    )
                }
                .buttonStyle(.plain)

                Text(entries.count < 4
                     ? "不用写很多，只要先认真写下一段标题和正文，生活页就会慢慢有真正的记录感。"
                     : "想起一个今天值得留下的小瞬间时，就把它写成一条完整记录放进来。")
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
                    .fill(AppTheme.Colors.glow.opacity(0.42))
                    .frame(width: 210, height: 210)
                    .blur(radius: 34)
                    .offset(x: 130, y: -70)

                Circle()
                    .fill(AppTheme.Colors.softAccent.opacity(0.34))
                    .frame(width: 170, height: 170)
                    .blur(radius: 22)
                    .offset(x: -120, y: 96)
            }
        )
        .appCardSurface(
            LinearGradient(
                colors: [
                    Color.white,
                    AppTheme.Colors.softAccent.opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            cornerRadius: AppTheme.CornerRadius.hero,
            borderColor: AppTheme.Colors.divider
        )
    }

    func featuredCard(entry: MemoryTimelineEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                Text(entry.dateText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.deepAccent)
                    .fixedSize(horizontal: true, vertical: false)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        MemoryCategoryTag(category: entry.category)
                        PageMetaPill(text: entry.recordContextText, systemImage: "book.closed")
                        PageMetaPill(text: "值得反复翻看", emphasis: true)
                    }
                    .padding(.vertical, 1)
                }

                Spacer(minLength: 0)

                if canManageEntries {
                    MemoryEntryMenu(
                        onEdit: {
                            editingEntry = entry
                        },
                        onDelete: {
                            pendingDeleteEntry = entry
                        }
                    )
                    .zIndex(1)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text(entry.body)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(5)

                    if !entry.metaItems.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.compact) {
                                ForEach(entry.metaItems) { item in
                                    PageMetaPill(text: item.text, systemImage: item.symbol)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }

                MemoryPhotoThumbnail(
                    entry: entry,
                    width: 114,
                    height: 150,
                    cornerRadius: AppTheme.CornerRadius.large
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    AppTheme.Colors.softAccent.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Text("第一条生活记录，还可以等一个刚刚好的时刻再写")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text("也许是一顿饭后的散步，也许是一个很普通但不想忘记的晚上。等那个片段出现，就把标题和正文认真写下来。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            Text("这里会替你们把生活里的小温度慢慢收起来。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)

            Button {
                isPresentingAddSheet = true
            } label: {
                PageCTAButton(text: "写下第一篇生活记录", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    AppTheme.Colors.softAccent.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    struct MemorySection: Identifiable {
        let id = UUID()
        let title: String
        let entries: [MemoryTimelineEntry]
        let sortDate: Date
    }
}
