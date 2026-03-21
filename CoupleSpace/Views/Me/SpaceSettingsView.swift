import SwiftUI
import UIKit

struct SpaceSettingsView: View {
    @EnvironmentObject private var relationshipStore: RelationshipStore
    @EnvironmentObject private var accountSessionStore: AccountSessionStore

    let initialAction: SpaceSettingsEntryAction?
    let onRequireLogin: ((SpaceSettingsEntryAction) -> Void)?

    @State private var activeSheet: SpaceSettingsEntryAction?
    @State private var lastAutoPresentedAction: SpaceSettingsEntryAction?
    @State private var isPresentingNicknameEditor = false

    init(
        initialAction: SpaceSettingsEntryAction? = nil,
        onRequireLogin: ((SpaceSettingsEntryAction) -> Void)? = nil
    ) {
        self.initialAction = initialAction
        self.onRequireLogin = onRequireLogin
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
                        subtitle: "创建或加入同一个共享空间。",
                        symbol: "person.2.fill"
                    ) {
                        VStack(spacing: 14) {
                            relationshipStatusCard

                            relationshipActions
                        }
                    }

                    AppSectionCard(
                        title: "空间显示",
                        subtitle: "首页展示和提醒节奏。",
                        symbol: "rectangle.on.rectangle"
                    ) {
                        VStack(spacing: 14) {
                            settingsLine(
                                title: "首页展示",
                                subtitle: "关系概览和主要入口的展示方式。"
                            )

                            settingsLine(
                                title: "提醒节奏",
                                subtitle: "纪念日和日常提醒。"
                            )
                        }
                    }

                    AppSectionCard(
                        title: "空间资料",
                        subtitle: "空间风格和双人资料。",
                        symbol: "sparkles"
                    ) {
                        VStack(spacing: 14) {
                            settingsLine(
                                title: "页面风格",
                                subtitle: "当前空间的页面风格。"
                            )

                            settingsNavigationLine(
                                title: "双人资料",
                                subtitle: nicknameEditorSubtitle
                            ) {
                                isPresentingNicknameEditor = true
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.page)
            }
        }
        .navigationTitle("空间设置")
        .secondaryPageNavigationStyle()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                CreateRelationshipSheet(
                    currentNickname: relationshipStore.state.currentUser.nickname,
                    partnerNickname: relationshipStore.state.partner?.nickname ?? ""
                ) { currentNickname, partnerNickname in
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
                    try await relationshipStore.joinSpace(
                        currentNickname: currentNickname,
                        partnerNickname: partnerNickname,
                        inviteCode: inviteCode
                    )
                }
            }
        }
        .sheet(isPresented: $isPresentingNicknameEditor) {
            PartnerNicknameEditorSheet()
        }
        .onAppear {
            Task {
                await relationshipStore.refreshRemoteRelationshipStatusIfNeeded()
            }
            presentInitialActionIfNeeded()
        }
        .onChange(of: initialAction) { _, _ in
            presentInitialActionIfNeeded()
        }
        .onChange(of: relationshipStore.state.relationStatus) { _, _ in
            presentInitialActionIfNeeded()
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
                    nickname: relationshipStore.currentUserDisplayName,
                    initials: relationshipStore.currentUserDisplayInitials,
                    title: "当前用户",
                    isDimmed: false
                )

                personUnit(
                    nickname: relationshipStore.partnerDisplayNameResolved,
                    initials: relationshipStore.partnerDisplayInitials,
                    title: relationshipStore.state.isBound ? "伴侣" : "等待加入",
                    isDimmed: !relationshipStore.state.isBound
                )
            }

            if let space = relationshipStore.state.space {
                HStack(spacing: 8) {
                    detailPill(text: relationshipStore.resolvedSpaceDisplayTitle, systemImage: "sparkles")
                    detailPill(
                        text: space.isActivated ? "已绑定" : "等待对方",
                        systemImage: space.isActivated ? "checkmark.circle.fill" : "clock"
                    )
                }
            }

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
                        openRelationshipEntry(.create)
                    } label: {
                        PageCTAButton(text: "创建共享空间", systemImage: "heart")
                    }
                    .buttonStyle(.plain)

                    Button {
                        openRelationshipEntry(.join)
                    } label: {
                        PageActionPill(text: "输入邀请码加入", systemImage: "number")
                    }
                    .buttonStyle(.plain)
                }

                Text("你创建空间后把邀请码发给对方；如果已经拿到邀请码，直接输入加入。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)

            case .inviting:
                HStack(spacing: 10) {
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
                    ? "把邀请码发给对方，对方输入后就会完成绑定。"
                    : "现在可以把邀请码发给对方，也可以先完成这一步。"
                )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)

            case .paired:
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = relationshipStore.state.space?.inviteCode
                    } label: {
                        PageActionPill(
                            text: "查看邀请码",
                            systemImage: "doc.on.doc"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("当前已经处于双人共享空间状态。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }
        }
    }

    private func openRelationshipEntry(_ action: SpaceSettingsEntryAction) {
        guard accountSessionStore.state.isLoggedIn else {
            onRequireLogin?(action)
            return
        }

        activeSheet = action
    }

    private func presentInitialActionIfNeeded() {
        guard relationshipStore.state.relationStatus == .unpaired else { return }
        guard activeSheet == nil else { return }
        guard let initialAction else { return }
        guard lastAutoPresentedAction != initialAction else { return }

        activeSheet = initialAction
        lastAutoPresentedAction = initialAction
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
            return "从这里创建共享空间，或者输入邀请码加入。"
        case .inviting:
            return "当前邀请码是 \(relationshipStore.state.inviteCode ?? "--")。等 \(relationshipStore.partnerDisplayNameResolved) 加入后，这里会更新为已绑定。"
        case .paired:
            return "当前已与 \(relationshipStore.partnerDisplayNameResolved) 绑定，你们已经进入同一个共享空间。"
        }
    }

    private var nicknameEditorSubtitle: String {
        "本机备注名：\(relationshipStore.currentUserDisplayName) / \(relationshipStore.partnerDisplayNameResolved)"
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

    private func settingsNavigationLine(
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.subtitle.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .appCardSurface(
                AppTheme.Colors.cardSurface(.secondary),
                cornerRadius: AppTheme.CornerRadius.medium
            )
        }
        .buttonStyle(.plain)
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
                    Text("如果对方已经先创建好了空间，就把邀请码填进来。只有邀请码真实有效时，当前关系和共享空间状态才会切到和对方一致的同一个共享空间。")
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
