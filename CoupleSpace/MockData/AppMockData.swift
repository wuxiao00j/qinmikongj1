import Foundation

enum AppMockData {
    static let homeCouple = HomeCouple(
        first: HomePartner(name: "Alex", initials: "A"),
        second: HomePartner(name: "Sarah", initials: "S"),
        sinceText: "May 12, 2024",
        relationshipDays: 628,
        note: "今天也在各自忙碌里，给彼此留了一点温柔。"
    )

    static let todayStatuses: [DailyStatus] = [
        DailyStatus(personName: "Alex", mood: "忙碌中", tone: .mistBlue),
        DailyStatus(personName: "Sarah", mood: "有点累", tone: .powderPink)
    ]

    static let homeSharedStatus = HomeSharedStatus(
        summary: "各自忙碌，但晚上想一起散步。",
        updatedText: "刚刚同步",
        tone: .softGreen
    )

    static let nextAnniversary = AnniversaryHighlight(
        title: "629 天纪念",
        daysRemaining: 7,
        dateText: "Mar 22",
        note: "不用隆重安排，只要把那天留给彼此就很好。"
    )

    static let recentMessage = MessageHighlight(
        fromName: "Sarah",
        content: "今天会有点晚，但回去之后想听你讲讲白天发生的事。",
        timeText: "今天 18:40"
    )

    static let homeMemoryPreview = MemoryEntry(
        title: "下雨天一起绕路回家",
        detail: "撑着一把伞慢慢走，路有点远，但那晚反而舍不得太快到家。",
        dateText: "2026.03.02"
    )

    static let homeSnapshot = HomeSnapshot(
        title: "属于两个人的安静角落",
        subtitle: "把日常、纪念和想念，收进同一个空间。",
        relationshipDays: 628,
        nextMilestone: "下一个纪念日还有 7 天"
    )

    static let homeStats: [QuickStat] = [
        QuickStat(title: "今日问候", value: "2 次", note: "保持联系的节奏刚刚好", symbol: "message"),
        QuickStat(title: "一起计划", value: "1 项", note: "周末晚餐与散步", symbol: "calendar"),
        QuickStat(title: "心情记录", value: "温柔", note: "今天适合慢一点", symbol: "heart")
    ]

    static let lifeEntries: [LifeEntry] = [
        LifeEntry(title: "今晚吃什么", detail: "先保留一个轻量入口，后续可接共同清单。", symbol: "fork.knife"),
        LifeEntry(title: "本周安排", detail: "用占位内容预留双人日程与提醒模块。", symbol: "list.bullet.clipboard"),
        LifeEntry(title: "小习惯", detail: "未来可以扩展打卡、默契任务与生活仪式感。", symbol: "checkmark.circle")
    ]

    static let dinnerSuggestions: [DinnerSuggestion] = [
        DinnerSuggestion(title: "日料", note: "清爽一点的晚饭", symbol: "fish"),
        DinnerSuggestion(title: "火锅", note: "适合慢慢吃一顿", symbol: "flame"),
        DinnerSuggestion(title: "楼下小馆", note: "不想走太远的时候", symbol: "storefront"),
        DinnerSuggestion(title: "点外卖", note: "回家也能一起吃", symbol: "bag")
    ]

    static let weeklyPlans: [WeeklyPlanItem] = [
        WeeklyPlanItem(
            title: "周五晚电影",
            note: "下班后直接去，不要太赶。",
            date: date(2026, 3, 20, 19, 30)
        ),
        WeeklyPlanItem(
            title: "周日去超市",
            note: "顺便把下周早餐和水果一起买了。",
            date: date(2026, 3, 22, 11, 0)
        ),
        WeeklyPlanItem(
            title: "下周一起吃顿好的",
            note: "找一家想去很久但一直没订的店。",
            date: date(2026, 3, 26, 20, 0)
        )
    ]

    static let placeWishes: [PlaceWish] = [
        PlaceWish(
            title: "去海边咖啡馆坐一下午",
            detail: "挑一个天气刚好的周末，慢慢喝东西，也慢慢看海。",
            note: "想把这件事留给不赶时间的一天。",
            category: .travel,
            status: .dreaming,
            targetText: "等天气转暖",
            symbol: "mug.fill"
        ),
        PlaceWish(
            title: "把那家想去很久的餐厅订下来",
            detail: "认真吃一顿晚饭，不庆祝什么，只是想完整待在一起。",
            note: "可以放在下个月的一个周五晚上。",
            category: .date,
            status: .planning,
            targetText: "下个月",
            symbol: "fork.knife"
        ),
        PlaceWish(
            title: "一起逛一次夜市",
            detail: "边走边吃，不设路线，看到什么就临时决定。",
            note: "更像一次轻松的小出逃。",
            category: .daily,
            status: .dreaming,
            targetText: "最近某个晚上",
            symbol: "moon.stars.fill"
        ),
        PlaceWish(
            title: "做一本属于我们的旅行相册",
            detail: "把已经去过的地方慢慢整理出来，留给以后反复翻看。",
            note: "不急着一次完成，慢慢做也很好。",
            category: .longTerm,
            status: .planning,
            targetText: "今年内",
            symbol: "book.closed.fill"
        ),
        PlaceWish(
            title: "第一次一起看海",
            detail: "已经实现了，但还是会想起那次出发前很轻的期待感。",
            note: "后来发现，真正想记住的是那一路都在一起。",
            category: .travel,
            status: .completed,
            targetText: "2025 秋天",
            symbol: "water.waves"
        )
    ]

    static let rituals: [RitualItem] = [
        RitualItem(title: "睡前说晚安", detail: "哪怕只是很短的一句，也想让彼此知道今天平安结束了。", symbol: "moon"),
        RitualItem(title: "每周一起散步一次", detail: "不一定很久，但想保留一起慢慢走的时间。", symbol: "figure.walk"),
        RitualItem(title: "一月留一天只属于彼此", detail: "不安排太多事情，只是完整地待在一起。", symbol: "heart")
    ]

    static let memoryEntries: [MemoryEntry] = [
        MemoryEntry(title: "第一次一起看海", detail: "这里先展示最近的一条记忆卡片，后续再接相册与时间轴。", dateText: "2025.08.17"),
        MemoryEntry(title: "冬日深夜散步", detail: "保留留白和层次，让记忆页更像真实产品而不是演示列表。", dateText: "2025.12.04")
    ]

    static let memoryTimelineEntries: [MemoryTimelineEntry] = [
        MemoryTimelineEntry(
            title: "下雨天一起绕路回家",
            detail: "明明都可以直接打车回去，却还是撑着一把伞慢慢走。路有点远，鞋边也湿了，但那段路后来一直很想再重来一次。",
            date: date(2026, 3, 10),
            category: .daily,
            imageLabel: "Rain Walk",
            mood: "很安静",
            location: "回家路上",
            weather: "小雨",
            isFeatured: true
        ),
        MemoryTimelineEntry(
            title: "厨房里那顿临时决定的宵夜",
            detail: "本来都准备各自休息了，最后还是翻出冰箱里的东西随便煮了点吃的，边做边聊，夜就慢慢变得很柔和。",
            date: date(2026, 3, 9),
            category: .daily,
            imageLabel: "Late Kitchen",
            mood: "放松",
            location: "家里",
            weather: "夜里有风"
        ),
        MemoryTimelineEntry(
            title: "天气很好的傍晚一起多走了一站",
            detail: "谁都没有提赶时间，就只是顺着那条路继续往前走。后来回头想，那种没有目的地的并肩感很难得。",
            date: date(2026, 3, 8),
            category: .date,
            imageLabel: "Longer Walk",
            mood: "轻松",
            location: "地铁口附近",
            weather: "晴天"
        ),
        MemoryTimelineEntry(
            title: "一起去海边躲开城市",
            detail: "那两天没有排太满的行程，只是看海、散步、拍下彼此很放松的样子。真正想记住的不是景点，而是我们都很松弛。",
            date: date(2025, 10, 11),
            category: .travel,
            imageLabel: "Sea Escape",
            mood: "很自由",
            location: "海边",
            weather: "海风很大"
        ),
        MemoryTimelineEntry(
            title: "第一次认真约会的那天",
            detail: "晚饭后没有急着回去，只是慢慢走，话题从天气聊到了未来想住的城市。现在回看，很多靠近好像都是从那个晚上开始的。",
            date: date(2025, 3, 18),
            category: .date,
            imageLabel: "Dinner Walk"
        ),
        MemoryTimelineEntry(
            title: "在一起一周年",
            detail: "没有刻意做很多安排，只是把那天完整留给彼此，就已经足够特别。",
            date: date(2025, 5, 12),
            category: .milestone,
            imageLabel: "One Year",
            mood: "很郑重",
            location: "留给彼此的一天",
            weather: "傍晚很温柔"
        )
    ]

    static let anniversaries: [AnniversaryItem] = [
        AnniversaryItem(
            title: "在一起纪念日",
            date: date(2024, 5, 12),
            category: .together,
            note: "从那天开始，很多平常的日子都慢慢有了被期待的理由。",
            cadence: .yearly
        ),
        AnniversaryItem(
            title: "629 天纪念",
            date: date(2026, 3, 22),
            category: .milestone,
            note: "不用特别隆重，只想把那一天安静地留出来。",
            cadence: .once
        ),
        AnniversaryItem(
            title: "Sarah 的生日",
            date: date(2024, 7, 6),
            category: .birthday,
            note: "想提前一点准备，不让喜欢的人在重要日子里匆忙。",
            cadence: .yearly
        ),
        AnniversaryItem(
            title: "第一次旅行",
            date: date(2025, 10, 11),
            category: .travel,
            note: "那次出发以后，连一起赶路都变成了会反复想起的记忆。",
            cadence: .yearly
        )
    ]

    static let profile = PartnerProfile(
        nickname: "Barry & You",
        signature: "把平凡日常，认真收藏。",
        city: "Shanghai"
    )

    static let relationshipSpaceProfile = RelationshipSpaceProfile(
        title: "Alex & Sarah",
        subtitle: "把平凡生活认真留给彼此。",
        city: "Shanghai",
        spaceTag: "双人空间",
        relationshipDays: 628,
        createdText: "空间建立于 2024.05"
    )

    static let spaceInsights: [SpaceInsight] = [
        SpaceInsight(title: "共同记忆", value: "14 条", note: "已经慢慢留下了一些想反复回看的时刻"),
        SpaceInsight(title: "下个纪念日", value: "7 天", note: "不用很隆重，但想把那天安静地留出来"),
        SpaceInsight(title: "最近更新", value: "3 月 2 日", note: "最近新添的是一段下雨天绕路回家的记忆")
    ]

    static let spaceSettingsItems: [SettingsItem] = [
        SettingsItem(
            title: "空间设置",
            subtitle: "主题、提醒与展示方式",
            symbol: "gearshape",
            destination: .spaceSettings
        ),
        SettingsItem(
            title: "纪念日管理",
            subtitle: "重要日期与提醒节奏",
            symbol: "calendar.badge.clock",
            destination: .anniversaryManagement
        ),
        SettingsItem(
            title: "关于我们",
            subtitle: "双人资料与空间介绍",
            symbol: "person.2",
            destination: .none
        )
    ]

    static let personalSettingsItems: [SettingsItem] = [
        SettingsItem(
            title: "提醒设置",
            subtitle: "记忆提醒、纪念日与生活小通知",
            symbol: "bell.badge",
            destination: .none
        ),
        SettingsItem(
            title: "展示偏好",
            subtitle: "首页模块顺序与页面展示方式",
            symbol: "slider.horizontal.3",
            destination: .none
        ),
        SettingsItem(
            title: "隐私入口",
            subtitle: "空间可见性与本地内容保护",
            symbol: "lock.shield",
            destination: .none
        )
    ]

    static let profileActions: [ProfileAction] = [
        ProfileAction(title: "空间设置", subtitle: "主题、提醒与展示偏好", symbol: "gearshape"),
        ProfileAction(title: "纪念日管理", subtitle: "后续扩展重要日期与提醒", symbol: "calendar.badge.clock"),
        ProfileAction(title: "关于我们", subtitle: "预留双人资料与空间介绍", symbol: "person.2")
    ]

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ) ?? .now
    }
}
