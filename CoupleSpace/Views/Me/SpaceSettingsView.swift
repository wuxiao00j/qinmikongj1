import SwiftUI
import UIKit

struct SpaceSettingsView: View {
    @EnvironmentObject private var relationshipStore: RelationshipStore

    let initialAction: SpaceSettingsEntryAction?

    @State private var activeSheet: SpaceSettingsEntryAction?
    @State private var copiedInviteCode = false
    @State private var isPresentingResetRelationshipAlert = false
    @State private var hasPresentedInitialAction = false

    init(initialAction: SpaceSettingsEntryAction? = nil) {
        self.initialAction = initialAction
    }

    var body: some View {
        ZStack {
            AppAtmosphereBackground(
                primaryGlow: AppTheme.Colors.softAccent.opacity(0.22),
                secondaryGlow: AppTheme.Colors.glow.opacity(0.18),
                primaryOffset: CGSize(width: -120, height: -240),
                secondaryOffset: CGSize(width: 130, height: -45)
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                    AppSectionCard(
                        title: "共享关系",
                        subtitle: "先把你们属于同一个空间这件事安静地确定下来，后面的记录和计划才会真正有归属。",
                        symbol: "person.2.fill"
                    ) {
                        VStack(spacing: 14) {
                            relationshipStatusCard

                            relationshipActions

                            if relationshipStore.state.relationStatus != .unpaired {
                                VStack(alignment: .leading, spacing: 8) {
                                    Button {
                                        isPresentingResetRelationshipAlert = true
                                    } label: {
                                        PageActionPill(text: "重新设置关系", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Text("退出后会先回到本地空间。当前共享空间里的内容不会立刻显示在眼前，但这不是直接删除所有内容。")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.subtitle)
                                        .lineSpacing(3)
                                }
                            }
                        }
                    }

                    AppSectionCard(
                        title: "空间显示",
                        subtitle: "先把空间的节奏调到更适合你们现在的生活",
                        symbol: "rectangle.on.rectangle"
                    ) {
                        VStack(spacing: 14) {
                            settingsLine(
                                title: "首页展示",
                                subtitle: "让关系概览、生活和记忆入口更贴近你们现在的节奏。"
                            )

                            settingsLine(
                                title: "提醒节奏",
                                subtitle: "纪念日和生活提醒可以更安静一点，不打扰，但别错过。"
                            )
                        }
                    }

                    AppSectionCard(
                        title: "空间氛围",
                        subtitle: "保持现在的留白感，也为以后留一些调整空间",
                        symbol: "sparkles"
                    ) {
                        VStack(spacing: 14) {
                            settingsLine(
                                title: "卡片风格",
                                subtitle: "保留现在的轻层次和柔和色彩，后续可以扩展更多主题。"
                            )

                            settingsLine(
                                title: "双人资料",
                                subtitle: "名字、城市和空间信息都可以在这里慢慢调整。"
                            )
                        }
                    }
                }
                .padding(AppTheme.Spacing.page)
            }
        }
        .navigationTitle("空间设置")
        .secondaryPageNavigationStyle()
        .alert(
            "重新设置关系？",
            isPresented: $isPresentingResetRelationshipAlert
        ) {
            Button("重新设置", role: .destructive) {
                copiedInviteCode = false
                relationshipStore.resetDemo()
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("这会退出当前共享空间，并先切回本地空间查看内容。当前共享空间里的记录、愿望和纪念日不会立刻显示在眼前，但这不是直接删除所有内容。")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                CreateRelationshipSheet(
                    currentNickname: relationshipStore.state.currentUser.nickname,
                    partnerNickname: relationshipStore.state.partner?.nickname ?? ""
                ) { currentNickname, partnerNickname in
                    copiedInviteCode = false
                    try await relationshipStore.createSpace(
                        currentNickname: currentNickname,
                        partnerNickname: partnerNickname
                    )
                }
            case .join:
                JoinRelationshipSheet(
                    currentNickname: relationshipStore.state.currentUser.nickname,
                    partnerNickname: relationshipStore.state.partner?.nickname ?? "",
                    inviteCode: relationshipStore.state.inviteCode ?? ""
                ) { currentNickname, partnerNickname, inviteCode in
                    copiedInviteCode = false
                    try await relationshipStore.joinSpace(
                        currentNickname: currentNickname,
                        partnerNickname: partnerNickname,
                        inviteCode: inviteCode
                    )
                }
            }
        }
        .onAppear {
            Task {
                await relationshipStore.refreshRemoteRelationshipStatusIfNeeded()
            }
            guard !hasPresentedInitialAction else { return }
            guard relationshipStore.state.relationStatus == .unpaired else { return }
            guard let initialAction else { return }
            activeSheet = initialAction
            hasPresentedInitialAction = true
        }
    }

    private var relationshipStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                PageMetaPill(
                    text: relationshipStore.state.relationStatus.label,
                    systemImage: relationshipStore.state.relationStatus.symbol,
                    emphasis: relationshipStore.state.relationStatus == .paired
                )

                Spacer(minLength: 12)

                if let code = relationshipStore.state.inviteCode, relationshipStore.state.hasPendingInvite {
                    Text(code)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.deepAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.cardSurface(.tertiary))
                        .clipShape(Capsule())
                }
            }

            Text(statusHeadline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            Text(statusBody)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)

            HStack(spacing: 12) {
                personUnit(
                    nickname: relationshipStore.state.currentUser.nickname,
                    initials: relationshipStore.state.currentUser.initials,
                    title: "当前用户",
                    isDimmed: false
                )

                personUnit(
                    nickname: relationshipStore.state.partnerDisplayName,
                    initials: relationshipStore.state.partner?.initials ?? "+",
                    title: relationshipStore.state.isBound ? "伴侣" : "等待加入",
                    isDimmed: !relationshipStore.state.isBound
                )
            }

            if let space = relationshipStore.state.space {
                HStack(spacing: 8) {
                    detailPill(text: space.title, systemImage: "sparkles")
                    detailPill(
                        text: space.isActivated ? "空间已激活" : "等待对方",
                        systemImage: space.isActivated ? "checkmark.circle.fill" : "clock"
                    )
                }
            }

            Text(AccountSyncCopy.localStorageSummary)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
            cornerRadius: AppTheme.CornerRadius.large
        )
    }

    private var relationshipActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch relationshipStore.state.relationStatus {
            case .unpaired:
                HStack(spacing: 10) {
                    Button {
                        activeSheet = .create
                    } label: {
                        PageCTAButton(text: "创建共享空间", systemImage: "heart")
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .join
                    } label: {
                        PageActionPill(text: "输入邀请码加入", systemImage: "number")
                    }
                    .buttonStyle(.plain)
                }

                Text("如果你先创建空间，就把邀请码发给对方；如果对方已经建好了，也可以直接输入邀请码加入。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)

            case .inviting:
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = relationshipStore.state.inviteCode
                        copiedInviteCode = true
                    } label: {
                        PageActionPill(
                            text: copiedInviteCode ? "邀请码已复制" : "复制邀请码",
                            systemImage: "doc.on.doc"
                        )
                    }
                    .buttonStyle(.plain)

                    if relationshipStore.state.connectionMode == .localDemo {
                        Button {
                            relationshipStore.completeInvitation()
                        } label: {
                            PageCTAButton(text: "完成邀请", systemImage: "person.2.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(
                    relationshipStore.state.isUsingBackendConnection
                    ? "现在可以把邀请码发给对方。只有对方在另一端输入这枚真实邀请码后，这个空间才会正式切到双人共享状态。"
                    : "现在可以把邀请码发给对方；如果只是想先把空间设置继续走完，也可以直接完成这一步。以后开启账号后，这段关系也会继续接到云端。"
                )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)

            case .paired:
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = relationshipStore.state.space?.inviteCode
                        copiedInviteCode = true
                    } label: {
                        PageActionPill(
                            text: copiedInviteCode ? "邀请码已复制" : "查看邀请码",
                            systemImage: "doc.on.doc"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("现在已经处于双人共享空间状态。以后开启账号后，“我的”页里的账号与同步会继续承接换机恢复、云端空间和双方同步。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }
        }
    }

    private var statusHeadline: String {
        switch relationshipStore.state.relationStatus {
        case .unpaired:
            return "还没有进入双人共享空间"
        case .inviting:
            return "空间已经创建，正在等待对方加入"
        case .paired:
            return "你们已经进入同一个共享空间"
        }
    }

    private var statusBody: String {
        switch relationshipStore.state.relationStatus {
        case .unpaired:
            return "从这里创建共享空间，或者输入已经拿到的邀请码加入。连上后端后，空间信息和关系状态会直接按真实结果承接回来。"
        case .inviting:
            return "当前邀请码是 \(relationshipStore.state.inviteCode ?? "--")。等 \(relationshipStore.state.partnerDisplayName) 加入之后，这个空间会从邀请中切换到已绑定。"
        case .paired:
            return "当前已与 \(relationshipStore.state.partnerDisplayName) 绑定，空间状态已激活。这个结果会保存在本地，重新打开 App 之后仍然会保留；以后账号能力开启后，也会继续支持换机恢复和双端同步。"
        }
    }

    private func personUnit(
        nickname: String,
        initials: String,
        title: String,
        isDimmed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isDimmed
                        ? AppTheme.Colors.cardSurface(.secondary)
                        : AppTheme.Colors.softAccent.opacity(0.62)
                    )

                Text(initials)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.title)
            }
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(isDimmed ? AppTheme.Colors.divider : Color.white.opacity(0.92), lineWidth: 2.5)
            )

            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.subtitle)

            Text(nickname)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
        .opacity(isDimmed ? 0.82 : 1)
    }

    private func detailPill(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))

            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(AppTheme.Colors.deepAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.Colors.cardSurface(.tertiary))
        .clipShape(Capsule())
    }

    private func settingsLine(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.title)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCardSurface(
            AppTheme.Colors.cardSurface(.secondary),
            cornerRadius: AppTheme.CornerRadius.medium
        )
    }
}

enum SpaceSettingsEntryAction: String, Identifiable {
    case create
    case join

    var id: String { rawValue }
}

private struct CreateRelationshipSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String, String) async throws -> Void

    @State private var currentNickname: String
    @State private var partnerNickname: String
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    init(
        currentNickname: String,
        partnerNickname: String,
        onCreate: @escaping (String, String) async throws -> Void
    ) {
        self.onCreate = onCreate
        _currentNickname = State(initialValue: currentNickname)
        _partnerNickname = State(initialValue: partnerNickname)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("先创建一个属于你们的空间，再把邀请码发给对方。创建成功后会拿到一枚真实可用的邀请码，之后会继续由对方输入邀请码加入。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }
                .listRowBackground(Color.clear)

                Section("昵称信息") {
                    TextField("你的昵称", text: $currentNickname)
                    TextField("对方昵称", text: $partnerNickname)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .listRowBackground(AppTheme.Colors.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("创建共享空间")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("生成邀请码") {
                        errorMessage = nil
                        isSubmitting = true
                        Task {
                            do {
                                try await onCreate(currentNicknameTrimmed, partnerNicknameTrimmed)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isSubmitting = false
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(currentNicknameTrimmed.isEmpty || isSubmitting)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
    }

    private var currentNicknameTrimmed: String {
        currentNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var partnerNicknameTrimmed: String {
        partnerNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct JoinRelationshipSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onJoin: (String, String, String) async throws -> Void

    @State private var currentNickname: String
    @State private var partnerNickname: String
    @State private var inviteCode: String
    @State private var joinErrorMessage: String?
    @State private var isSubmitting = false

    init(
        currentNickname: String,
        partnerNickname: String,
        inviteCode: String,
        onJoin: @escaping (String, String, String) async throws -> Void
    ) {
        self.onJoin = onJoin
        _currentNickname = State(initialValue: currentNickname)
        _partnerNickname = State(initialValue: partnerNickname)
        _inviteCode = State(initialValue: inviteCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("如果对方已经先创建好了空间，就把邀请码填进来。只有邀请码真实有效时，当前关系和共享空间状态才会继续切到同一个后端空间。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }
                .listRowBackground(Color.clear)

                Section("加入信息") {
                    TextField("你的昵称", text: $currentNickname)
                    TextField("对方昵称", text: $partnerNickname)
                    TextField("邀请码", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                }
                .listRowBackground(AppTheme.Colors.cardBackground)

                if let joinErrorMessage {
                    Section {
                        Text(joinErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                    .listRowBackground(AppTheme.Colors.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("输入邀请码加入")
            .secondaryPageNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("加入空间") {
                        joinErrorMessage = nil
                        isSubmitting = true
                        Task {
                            do {
                                try await onJoin(currentNicknameTrimmed, partnerNicknameTrimmed, inviteCodeTrimmed)
                                dismiss()
                            } catch {
                                joinErrorMessage = error.localizedDescription
                            }
                            isSubmitting = false
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(currentNicknameTrimmed.isEmpty || inviteCodeTrimmed.isEmpty || isSubmitting)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
        .onChange(of: inviteCode) { _, _ in
            if joinErrorMessage != nil {
                joinErrorMessage = nil
            }
        }
    }

    private var currentNicknameTrimmed: String {
        currentNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var partnerNicknameTrimmed: String {
        partnerNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var inviteCodeTrimmed: String {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
