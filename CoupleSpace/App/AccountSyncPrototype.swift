import Combine
import Foundation

#if DEBUG
private func debugWhisperSync(_ message: @autoclosure () -> String) {
    print("[WhisperSync] \(message())")
}

private func debugAutomaticPush(_ message: @autoclosure () -> String) {
    print("[AutomaticPush] \(message())")
}

private func debugMemorySync(_ message: @autoclosure () -> String) {
    print("[MemorySync] \(message())")
}

private func debugWishSync(_ message: @autoclosure () -> String) {
    print("[WishSync] \(message())")
}

private func debugMemoryAssetSync(_ message: @autoclosure () -> String) {
    print("[MemoryAssetSync] \(message())")
}
#else
private func debugWhisperSync(_ message: @autoclosure () -> String) {}
private func debugAutomaticPush(_ message: @autoclosure () -> String) {}
private func debugMemorySync(_ message: @autoclosure () -> String) {}
private func debugWishSync(_ message: @autoclosure () -> String) {}
private func debugMemoryAssetSync(_ message: @autoclosure () -> String) {}
#endif

private let syncISO8601DateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let fallbackSyncISO8601DateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private func makeSyncJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = syncISO8601DateFormatter.date(from: value) {
            return date
        }
        if let date = fallbackSyncISO8601DateFormatter.date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date: \(value)"
        )
    }
    return decoder
}

private func makeSyncJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(syncISO8601DateFormatter.string(from: date))
    }
    return encoder
}

private func wishDebugSummary(_ wishes: [PlaceWish]) -> String {
    if wishes.isEmpty {
        return "[]"
    }

    let ids = wishes
        .sorted { $0.updatedAt < $1.updatedAt }
        .map {
            String(
                format: "%@|user=%@|updatedAt=%.6f|category=%@|status=%@",
                $0.id.uuidString.lowercased(),
                $0.createdByUserId,
                $0.updatedAt.timeIntervalSince1970,
                $0.category.rawValue,
                $0.status.rawValue
            )
        }
        .joined(separator: ",")
    return "[\(ids)]"
}

private func wishTombstoneDebugSummary(_ tombstones: [WishDeletionTombstone]) -> String {
    if tombstones.isEmpty {
        return "[]"
    }

    let ids = tombstones
        .sorted { $0.deletedAt < $1.deletedAt }
        .map {
            String(
                format: "%@|deletedBy=%@|deletedAt=%.6f",
                $0.id.uuidString.lowercased(),
                $0.deletedByUserId,
                $0.deletedAt.timeIntervalSince1970
            )
        }
        .joined(separator: ",")
    return "[\(ids)]"
}

// MARK: - Account Session

enum AccountSessionMode: String, Codable {
    case localOnly
    case cloudPrepared
    case cloudConnected

    var label: String {
        switch self {
        case .localOnly:
            return "本地模式"
        case .cloudPrepared:
            return "同步准备中"
        case .cloudConnected:
            return "云端已连接"
        }
    }
}

enum AccountSessionSource: String, Codable {
    case none
    case demo
    case authenticated

    var label: String {
        switch self {
        case .none:
            return "未开启账号"
        case .demo:
            return "开发接入"
        case .authenticated:
            return "已连接账号"
        }
    }

    var productLabel: String {
        switch self {
        case .none:
            return "未开启账号"
        case .demo:
            return "开发接入已开启"
        case .authenticated:
            return "账号已连接"
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            return "iphone"
        case .demo:
            return "wrench.and.screwdriver"
        case .authenticated:
            return "person.crop.circle.badge.checkmark"
        }
    }

    var productDescription: String {
        switch self {
        case .none:
            return "当前仍以本机保存为主，还没有开启账号会话。"
        case .demo:
            return "当前使用的是开发接入账号，主要用于测试联调；普通用户主路径仍应从正式登录入口进入。"
        case .authenticated:
            return "这里已经接入一份可用账号，会继续沿着这条状态线展示云端连接和同步结果。"
        }
    }
}

enum AccountCloudMode: String, Codable {
    case localOnly
    case prepared
    case enabled

    var label: String {
        switch self {
        case .localOnly:
            return "本地模式"
        case .prepared:
            return "同步准备中"
        case .enabled:
            return "云端已开启"
        }
    }
}

struct AccountProfile: Codable, Equatable {
    let accountId: String
    var nickname: String
    var providerName: String
    var detailText: String
}

// Future login handoff:
// 真实登录成功后，先把服务端返回收敛成这个轻量 payload，
// 再统一映射到 AccountProfile / AccountSessionState，避免把 UI 直接绑到后端字段上。
struct AuthenticatedAccountPayload: Codable, Equatable {
    let accountId: String
    let displayName: String
    let providerName: String
    let accountHint: String?
    let accessToken: String?
}

struct AccountSessionAuthorization: Codable, Equatable {
    let accessToken: String
    let tokenType: String

    static func fromAuthenticatedPayload(_ payload: AuthenticatedAccountPayload) -> AccountSessionAuthorization? {
        guard let rawToken = payload.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawToken.isEmpty == false else {
            return nil
        }

        return AccountSessionAuthorization(
            accessToken: rawToken,
            tokenType: "Bearer"
        )
    }
}

private func normalizedVisibleAppName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return "余白" }

    let normalized = trimmed.lowercased()
    let legacyNames = [
        "couplespace",
        "couple space",
        "情侣空间",
        "couple space account",
        "couple space id"
    ]

    return legacyNames.contains(normalized) ? "余白" : trimmed
}

extension AccountProfile {
    static func fromAuthenticatedPayload(_ payload: AuthenticatedAccountPayload) -> AccountProfile {
        let providerName = normalizedVisibleAppName(payload.providerName)
        let resolvedHint = payload.accountHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailText = resolvedHint?.isEmpty == false
            ? resolvedHint!
            : providerName

        return AccountProfile(
            accountId: payload.accountId,
            nickname: payload.displayName,
            providerName: providerName,
            detailText: detailText
        )
    }
}

struct AccountSessionState: Codable, Equatable {
    var account: AccountProfile?
    var authorization: AccountSessionAuthorization?
    var sessionSource: AccountSessionSource
    var cloudMode: AccountCloudMode
    var lastPreparedAt: Date?

    static let localDefault = AccountSessionState(
        account: nil,
        authorization: nil,
        sessionSource: .none,
        cloudMode: .localOnly,
        lastPreparedAt: nil
    )

    var isLoggedIn: Bool {
        account != nil && sessionSource != .none
    }

    var isDemoSession: Bool {
        sessionSource == .demo
    }

    var isCloudSyncEnabled: Bool {
        cloudMode != .localOnly
    }

    init(
        account: AccountProfile?,
        authorization: AccountSessionAuthorization?,
        sessionSource: AccountSessionSource,
        cloudMode: AccountCloudMode,
        lastPreparedAt: Date?
    ) {
        self.account = account
        self.authorization = authorization
        self.sessionSource = sessionSource
        self.cloudMode = cloudMode
        self.lastPreparedAt = lastPreparedAt
    }

    private enum CodingKeys: String, CodingKey {
        case account
        case authorization
        case sessionSource
        case cloudMode
        case lastPreparedAt
        case isCloudSyncEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let account = try container.decodeIfPresent(AccountProfile.self, forKey: .account)
        let authorization = try container.decodeIfPresent(AccountSessionAuthorization.self, forKey: .authorization)
        let sessionSource = try container.decodeIfPresent(AccountSessionSource.self, forKey: .sessionSource)
            ?? (account == nil ? .none : .demo)
        let cloudMode = try container.decodeIfPresent(AccountCloudMode.self, forKey: .cloudMode)
            ?? ((try container.decodeIfPresent(Bool.self, forKey: .isCloudSyncEnabled) ?? false) ? .prepared : .localOnly)
        let lastPreparedAt = try container.decodeIfPresent(Date.self, forKey: .lastPreparedAt)

        self.init(
            account: account,
            authorization: authorization,
            sessionSource: sessionSource,
            cloudMode: cloudMode,
            lastPreparedAt: lastPreparedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encodeIfPresent(authorization, forKey: .authorization)
        try container.encode(sessionSource, forKey: .sessionSource)
        try container.encode(cloudMode, forKey: .cloudMode)
        try container.encodeIfPresent(lastPreparedAt, forKey: .lastPreparedAt)
    }
}

struct LocalBackendConnectionConfiguration {
    let environmentLabel: String
    let baseURL: URL?
    let loginPath: String
    let demoLoginPath: String
    let snapshotPathTemplate: String
    let defaultDemoAccountID: String

    static let current = LocalBackendConnectionConfiguration(
        environmentLabel: "公网测试环境",
        baseURL: URL(string: "http://49.51.194.94:8787"),
        loginPath: "/auth/login",
        demoLoginPath: "/auth/demo-login",
        snapshotPathTemplate: "/spaces/{spaceId}/snapshot",
        defaultDemoAccountID: "acct-real-alex"
    )

    var loginURL: URL? {
        guard let baseURL else { return nil }
        return baseURL.appending(path: loginPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    var demoLoginURL: URL? {
        guard let baseURL else { return nil }
        return baseURL.appending(path: demoLoginPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    var baseURLDisplayText: String {
        baseURL?.absoluteString ?? "未配置"
    }

    var summaryText: String {
        "\(environmentLabel) 使用 \(baseURLDisplayText)，当前仅供设备测试，仍不是正式生产环境；上传和读取都会通过 \(snapshotPathTemplate) 手动触发。"
    }
}

// MARK: - Remote Contract

enum SyncRemoteAvailability: Equatable {
    case placeholder
    case connected

    var label: String {
        switch self {
        case .placeholder:
            return "待接入"
        case .connected:
            return "已连接"
        }
    }
}

// Future API 接入时，所有请求都以 accountId + currentUserId + spaceId 作为最小上下文。
// 这样既能承接账号体系，也能对齐当前已经存在的共享空间作用域。
struct AppSyncRequestContext {
    let accountId: String
    let currentUserId: String
    let partnerUserId: String?
    let spaceId: String
}

// 这是未来后端至少要接住的共享内容对象集合。
// 现在仍然直接承接本地模型，等真正接 API 时再在 remote provider 内做 DTO 映射即可。
struct SyncContentPayload {
    let scope: AppContentScope
    let memories: [MemoryTimelineEntry]
    let memoryTombstones: [MemoryDeletionTombstone]
    let wishes: [PlaceWish]
    let wishTombstones: [WishDeletionTombstone]
    let anniversaries: [AnniversaryItem]
    let weeklyTodos: [WeeklyTodoItem]
    let tonightDinners: [TonightDinnerOption]
    let rituals: [RitualItem]
    let currentStatuses: [CurrentStatusItem]
    let whisperNotes: [WhisperNoteItem]
    let relationStatus: CoupleRelationStatus
    let updatedAt: Date

    var totalCount: Int {
        memories.count + wishes.count + anniversaries.count + weeklyTodos.count + tonightDinners.count + rituals.count + currentStatuses.count + whisperNotes.count
    }

    var memoryCount: Int {
        memories.count
    }

    var memoryTombstoneCount: Int {
        memoryTombstones.count
    }

    var wishCount: Int {
        wishes.count
    }

    var anniversaryCount: Int {
        anniversaries.count
    }

    var weeklyTodoCount: Int {
        weeklyTodos.count
    }

    var tonightDinnerCount: Int {
        tonightDinners.count
    }

    var ritualCount: Int {
        rituals.count
    }

    var currentStatusCount: Int {
        currentStatuses.count
    }

    var whisperNoteCount: Int {
        whisperNotes.count
    }

    static func fromRemoteSnapshotPayload(_ payload: RemoteSyncSnapshotPayload) -> SyncContentPayload {
        SyncContentPayload(
            scope: payload.contentScope,
            memories: payload.memories,
            memoryTombstones: payload.memoryTombstones,
            wishes: payload.wishes,
            wishTombstones: payload.wishTombstones,
            anniversaries: payload.anniversaries,
            weeklyTodos: payload.weeklyTodos,
            tonightDinners: payload.tonightDinners,
            rituals: payload.rituals,
            currentStatuses: payload.currentStatuses,
            whisperNotes: payload.whisperNotes,
            relationStatus: payload.relationStatus,
            updatedAt: payload.updatedAt
        )
    }
}

// Future sync handoff:
// 真实同步接口返回后，先把远端结果整理成这个轻量 payload，
// 再统一映射到 SyncContentPayload，继续复用当前 apply / store replace 链路。
struct RemoteSyncSnapshotPayload {
    let snapshotId: String
    let spaceId: String
    let currentUserId: String
    let partnerUserId: String?
    let isSharedSpace: Bool
    let memories: [MemoryTimelineEntry]
    let memoryTombstones: [MemoryDeletionTombstone]
    let wishes: [PlaceWish]
    let wishTombstones: [WishDeletionTombstone]
    let anniversaries: [AnniversaryItem]
    let weeklyTodos: [WeeklyTodoItem]
    let tonightDinners: [TonightDinnerOption]
    let rituals: [RitualItem]
    let currentStatuses: [CurrentStatusItem]
    let whisperNotes: [WhisperNoteItem]
    let relationStatus: CoupleRelationStatus
    let updatedAt: Date

    var contentScope: AppContentScope {
        AppContentScope(
            currentUserId: currentUserId,
            partnerUserId: partnerUserId,
            spaceId: spaceId,
            isSharedSpace: isSharedSpace
        )
    }
}

struct SyncStatusSnapshot {
    let mode: AccountSessionMode
    let isUsingLocalData: Bool
    let accountDisplayName: String
    let providerLabel: String
    let availabilityLabel: String
    let hasRemoteContent: Bool
    let remoteSummary: SyncRemotePayloadSummary?
    let isSyncing: Bool
    let canApplyPulledContent: Bool
    let hasPendingPulledContent: Bool
    let pendingPulledContentText: String?
    let lastPushAt: Date?
    let lastPullAt: Date?
    let lastAppliedAt: Date?
    let latestEventText: String?
    let latestErrorText: String?
    let summary: String
    let detail: String
}

private struct ManualBackendSyncTarget {
    let scope: AppContentScope
    let context: AppSyncRequestContext
}

enum AppSyncPrototypeError: LocalizedError {
    case remoteUnavailable
    case remoteContentMissing
    case authenticatedSessionRequired
    case backendSpaceRequired
    case relationshipScopeMismatch

    var errorDescription: String? {
        switch self {
        case .remoteUnavailable:
            return "云端同步接口还没有接入。"
        case .remoteContentMissing:
            return "云端还没有一份可拉取的内容。"
        case .authenticatedSessionRequired:
            return "请先登录账号，再把当前空间同步到测试环境。"
        case .backendSpaceRequired:
            return "请先进入已连接后端的共享空间，再发送这次测试环境同步。"
        case .relationshipScopeMismatch:
            return "当前共享空间身份还没有和这份账号对齐，请先回到空间设置刷新关系状态后再试。"
        }
    }
}

struct SyncRemotePayloadSummary: Equatable {
    let spaceId: String
    let relationStatus: CoupleRelationStatus
    let memoryCount: Int
    let wishCount: Int
    let anniversaryCount: Int
    let weeklyTodoCount: Int
    let tonightDinnerCount: Int
    let ritualCount: Int
    let currentStatusCount: Int
    let whisperNoteCount: Int
    let updatedAt: Date

    var totalCount: Int {
        memoryCount + wishCount + anniversaryCount + weeklyTodoCount + tonightDinnerCount + ritualCount + currentStatusCount + whisperNoteCount
    }

    init(
        spaceId: String,
        relationStatus: CoupleRelationStatus,
        memoryCount: Int,
        wishCount: Int,
        anniversaryCount: Int,
        weeklyTodoCount: Int,
        tonightDinnerCount: Int,
        ritualCount: Int,
        currentStatusCount: Int,
        whisperNoteCount: Int,
        updatedAt: Date
    ) {
        self.spaceId = spaceId
        self.relationStatus = relationStatus
        self.memoryCount = memoryCount
        self.wishCount = wishCount
        self.anniversaryCount = anniversaryCount
        self.weeklyTodoCount = weeklyTodoCount
        self.tonightDinnerCount = tonightDinnerCount
        self.ritualCount = ritualCount
        self.currentStatusCount = currentStatusCount
        self.whisperNoteCount = whisperNoteCount
        self.updatedAt = updatedAt
    }

    init(payload: SyncContentPayload) {
        self.spaceId = payload.scope.spaceId
        self.relationStatus = payload.relationStatus
        self.memoryCount = payload.memoryCount
        self.wishCount = payload.wishCount
        self.anniversaryCount = payload.anniversaryCount
        self.weeklyTodoCount = payload.weeklyTodoCount
        self.tonightDinnerCount = payload.tonightDinnerCount
        self.ritualCount = payload.ritualCount
        self.currentStatusCount = payload.currentStatusCount
        self.whisperNoteCount = payload.whisperNoteCount
        self.updatedAt = payload.updatedAt
    }
}

enum AutomaticSyncTrigger: String {
    case memoriesChanged
    case wishesChanged
    case anniversariesChanged
    case weeklyTodosChanged
    case tonightDinnersChanged
    case ritualsChanged
    case currentStatusesChanged
    case whisperNotesChanged
    case appBecameActive
    case meViewAppeared
    case accountSyncAppeared
    case foregroundHeartbeat

    var automaticPushEventText: String {
        switch self {
        case .memoriesChanged:
            return "已自动同步最新记忆到测试环境"
        case .wishesChanged:
            return "已自动同步最新愿望改动到测试环境"
        case .anniversariesChanged:
            return "已自动同步最新纪念日改动到测试环境"
        case .weeklyTodosChanged:
            return "已自动同步最新本周事项到测试环境"
        case .tonightDinnersChanged:
            return "已自动同步最新今晚吃什么到测试环境"
        case .ritualsChanged:
            return "已自动同步最新小约定到测试环境"
        case .currentStatusesChanged:
            return "已自动同步最新当前状态到测试环境"
        case .whisperNotesChanged:
            return "已自动同步最新悄悄话到测试环境"
        case .appBecameActive, .meViewAppeared, .accountSyncAppeared:
            return "已自动同步最近内容到测试环境"
        case .foregroundHeartbeat:
            return "已自动同步最近内容到测试环境"
        }
    }

    var automaticPullEventText: String {
        switch self {
        case .appBecameActive:
            return "已在回到前台后检查最近云端快照"
        case .meViewAppeared:
            return "已在进入“我的”页时检查最近云端快照"
        case .accountSyncAppeared:
            return "已在进入“账号与同步”页时检查最近云端快照"
        case .foregroundHeartbeat:
            return "已自动检查最近共享内容"
        case .memoriesChanged, .wishesChanged, .anniversariesChanged, .weeklyTodosChanged, .tonightDinnersChanged, .ritualsChanged, .currentStatusesChanged, .whisperNotesChanged:
            return "已检查最近云端快照"
        }
    }
}

enum AppSyncRemoteProviderKind: String {
    case demoFakeRemote
    case productionReal

    var label: String {
        switch self {
        case .demoFakeRemote:
            return "内置云端"
        case .productionReal:
            return "云端服务"
        }
    }
}

struct AppSyncProviderConfiguration {
    let kind: AppSyncRemoteProviderKind

    // 默认仍保持 fake provider，避免工程启动后直接依赖本地后端环境。
    static let current = AppSyncProviderConfiguration(kind: .demoFakeRemote)

    var modeLabel: String {
        switch kind {
        case .demoFakeRemote:
            return "内置云端（默认）"
        case .productionReal:
            return "云端服务"
        }
    }

    var usageNote: String {
        switch kind {
        case .demoFakeRemote:
            return "默认先使用内置云端环境；如果需要连接开发后端，可在页面下方手动处理。"
        case .productionReal:
            return "只有在明确切换云端注入后，主同步链路才会整体改走真实服务。"
        }
    }

    func makeRemoteProvider(
        defaults: UserDefaults = .standard,
        accountSessionStore: AccountSessionStore? = nil
    ) -> any AppSyncRemoteProviding {
        switch kind {
        case .demoFakeRemote:
            return FakeSyncRemoteProvider(defaults: defaults)
        case .productionReal:
            return RealSyncRemoteProvider(accountSessionStore: accountSessionStore)
        }
    }
}

protocol AppSyncRemoteProviding {
    var providerKind: AppSyncRemoteProviderKind { get }
    var providerName: String { get }
    var availability: SyncRemoteAvailability { get }

    func pushContent(_ payload: SyncContentPayload, context: AppSyncRequestContext) async throws
    func pullContent(for context: AppSyncRequestContext) async throws -> SyncContentPayload
    func fetchRemoteSummary(for context: AppSyncRequestContext) async throws -> SyncRemotePayloadSummary?
}

struct RealSyncRemoteProviderConfiguration {
    let providerName: String
    let baseURL: URL?
    let requiresAuthenticatedSession: Bool
    let timeoutInterval: TimeInterval
    let defaultHeaders: [String: String]

    static let current = RealSyncRemoteProviderConfiguration(
        providerName: "测试环境 API",
        baseURL: LocalBackendConnectionConfiguration.current.baseURL,
        requiresAuthenticatedSession: true,
        timeoutInterval: 20,
        defaultHeaders: [
            "Accept": "application/json"
        ]
    )
}

enum LocalBackendDemoLoginError: LocalizedError {
    case baseURLMissing
    case requestEncodingFailed
    case backendUnavailable
    case requestFailed(detail: String)
    case invalidResponse
    case unexpectedStatusCode(Int, responseBody: String?)
    case responseDecodingFailed(detail: String)
    case requiredFieldMissing(field: String)

    var errorDescription: String? {
        switch self {
        case .baseURLMissing:
            return "测试环境地址还没有配置。"
        case .requestEncodingFailed:
            return "这次没有成功整理测试环境登录请求。"
        case .backendUnavailable:
            return "当前暂时连不上测试环境，请确认网络可用后再试。"
        case .requestFailed(let detail):
            return "连接测试环境账号失败：\(detail)"
        case .invalidResponse:
            return "测试环境返回了无法识别的响应。"
        case .unexpectedStatusCode(let statusCode, let responseBody):
            let suffix = responseBody?.isEmpty == false ? "（\(responseBody!)）" : ""
            return "测试环境登录返回了异常状态码 \(statusCode)\(suffix)"
        case .responseDecodingFailed(let detail):
            return "测试环境登录返回解码失败：\(detail)"
        case .requiredFieldMissing(let field):
            return "测试环境登录返回缺少关键字段：\(field)"
        }
    }
}

enum LocalBackendAccountLoginError: LocalizedError {
    case baseURLMissing
    case requestEncodingFailed
    case invalidCredentials
    case backendUnavailable
    case requestFailed(detail: String)
    case invalidResponse
    case unexpectedStatusCode(Int, responseBody: String?)
    case responseDecodingFailed(detail: String)
    case requiredFieldMissing(field: String)

    var errorDescription: String? {
        switch self {
        case .baseURLMissing:
            return "登录服务地址还没有配置。"
        case .requestEncodingFailed:
            return "这次没有成功整理登录请求。"
        case .invalidCredentials:
            return "邮箱或密码不正确。"
        case .backendUnavailable:
            return "当前暂时连不上测试环境，请确认网络可用后再试。"
        case .requestFailed(let detail):
            return "登录请求失败：\(detail)"
        case .invalidResponse:
            return "登录服务返回了无法识别的响应。"
        case .unexpectedStatusCode(let statusCode, let responseBody):
            let suffix = responseBody?.isEmpty == false ? "（\(responseBody!)）" : ""
            return "登录接口返回了异常状态码 \(statusCode)\(suffix)"
        case .responseDecodingFailed(let detail):
            return "登录返回解码失败：\(detail)"
        case .requiredFieldMissing(let field):
            return "登录返回缺少关键字段：\(field)"
        }
    }
}

private struct LocalBackendLoginRequestBody: Encodable {
    let email: String
    let password: String
}

struct LocalBackendAccountLoginClient {
    let configuration: LocalBackendConnectionConfiguration
    let session: URLSession

    init(
        configuration: LocalBackendConnectionConfiguration = .current,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func login(email: String, password: String) async throws -> AuthenticatedAccountPayload {
        guard let url = configuration.loginURL else {
            throw LocalBackendAccountLoginError.baseURLMissing
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(
                LocalBackendLoginRequestBody(
                    email: normalizedEmail,
                    password: normalizedPassword
                )
            )
        } catch {
            throw LocalBackendAccountLoginError.requestEncodingFailed
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = requestBody

        let responseData: Data
        let response: URLResponse

        do {
            (responseData, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotConnectToHost, .timedOut, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw LocalBackendAccountLoginError.backendUnavailable
            default:
                throw LocalBackendAccountLoginError.requestFailed(detail: urlError.localizedDescription)
            }
        } catch {
            throw LocalBackendAccountLoginError.requestFailed(detail: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalBackendAccountLoginError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw LocalBackendAccountLoginError.invalidCredentials
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LocalBackendAccountLoginError.unexpectedStatusCode(
                httpResponse.statusCode,
                responseBody: responseBodyPreview(from: responseData)
            )
        }

        let decoder = JSONDecoder()
        do {
            let payload = try decoder.decode(AuthenticatedAccountPayload.self, from: responseData)

            if payload.accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LocalBackendAccountLoginError.requiredFieldMissing(field: "accountId")
            }

            if payload.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LocalBackendAccountLoginError.requiredFieldMissing(field: "displayName")
            }

            if payload.providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LocalBackendAccountLoginError.requiredFieldMissing(field: "providerName")
            }

            guard let token = payload.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                  token.isEmpty == false else {
                throw LocalBackendAccountLoginError.requiredFieldMissing(field: "accessToken")
            }

            return AuthenticatedAccountPayload(
                accountId: payload.accountId,
                displayName: payload.displayName,
                providerName: payload.providerName,
                accountHint: payload.accountHint,
                accessToken: token
            )
        } catch let loginError as LocalBackendAccountLoginError {
            throw loginError
        } catch {
            throw LocalBackendAccountLoginError.responseDecodingFailed(detail: error.localizedDescription)
        }
    }

    private func responseBodyPreview(from data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            return nil
        }

        return String(text.prefix(160))
    }
}

struct LocalBackendDemoLoginClient {
    let configuration: LocalBackendConnectionConfiguration
    let session: URLSession

    init(
        configuration: LocalBackendConnectionConfiguration = .current,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func login(
        accountId: String? = nil,
        displayName: String? = nil
    ) async throws -> AuthenticatedAccountPayload {
        guard let url = configuration.demoLoginURL else {
            throw LocalBackendDemoLoginError.baseURLMissing
        }

        let requestBody: Data
        do {
            var requestPayload: [String: String] = [:]

            if let accountId, accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                requestPayload["accountId"] = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let displayName, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                requestPayload["displayName"] = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                requestPayload["accountId"] = configuration.defaultDemoAccountID
            }

            requestBody = try JSONSerialization.data(withJSONObject: requestPayload)
        } catch {
            throw LocalBackendDemoLoginError.requestEncodingFailed
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = requestBody

        let responseData: Data
        let response: URLResponse

        do {
            (responseData, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotConnectToHost, .timedOut, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw LocalBackendDemoLoginError.backendUnavailable
            default:
                throw LocalBackendDemoLoginError.requestFailed(detail: urlError.localizedDescription)
            }
        } catch {
            throw LocalBackendDemoLoginError.requestFailed(detail: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalBackendDemoLoginError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LocalBackendDemoLoginError.unexpectedStatusCode(
                httpResponse.statusCode,
                responseBody: responseBodyPreview(from: responseData)
            )
        }

        let decoder = JSONDecoder()
        do {
            let payload = try decoder.decode(AuthenticatedAccountPayload.self, from: responseData)

            if payload.accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LocalBackendDemoLoginError.requiredFieldMissing(field: "accountId")
            }

            if payload.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LocalBackendDemoLoginError.requiredFieldMissing(field: "displayName")
            }

            if payload.providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LocalBackendDemoLoginError.requiredFieldMissing(field: "providerName")
            }

            guard let token = payload.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                  token.isEmpty == false else {
                throw LocalBackendDemoLoginError.requiredFieldMissing(field: "accessToken")
            }

            return AuthenticatedAccountPayload(
                accountId: payload.accountId,
                displayName: payload.displayName,
                providerName: payload.providerName,
                accountHint: payload.accountHint,
                accessToken: token
            )
        } catch let loginError as LocalBackendDemoLoginError {
            throw loginError
        } catch {
            throw LocalBackendDemoLoginError.responseDecodingFailed(detail: error.localizedDescription)
        }
    }

    private func responseBodyPreview(from data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            return nil
        }

        return String(text.prefix(160))
    }
}

enum RealSyncRemoteProviderError: LocalizedError {
    case baseURLMissing
    case authenticatedSessionRequired
    case authorizationSourceMissing
    case backendUnavailable(operation: String)
    case requestFailed(operation: String, detail: String)
    case unexpectedStatusCode(operation: String, statusCode: Int, responseBody: String?)
    case responseDecodingFailed(operation: String, detail: String)
    case responsePayloadMismatch(operation: String, detail: String)
    case requestEncodingFailed(operation: String)
    case endpointNotImplemented(operation: String)

    var errorDescription: String? {
        switch self {
        case .baseURLMissing:
            return "云端连接尚未配置 base URL。"
        case .authenticatedSessionRequired:
            return "云端连接需要先接入一份可用账号。"
        case .authorizationSourceMissing:
            return "云端连接暂时还没有可用的鉴权信息。"
        case .backendUnavailable(let operation):
            return "云端同步的 \(operation) 暂时连不上测试环境，请确认当前网络可用。"
        case .requestFailed(let operation, let detail):
            return "云端同步的 \(operation) 请求没有发成功：\(detail)"
        case .unexpectedStatusCode(let operation, let statusCode, let responseBody):
            let suffix = responseBody?.isEmpty == false ? "（\(responseBody!)）" : ""
            return "云端同步的 \(operation) 返回了异常状态码 \(statusCode)\(suffix)"
        case .responseDecodingFailed(let operation, let detail):
            return "云端同步的 \(operation) 响应解码失败：\(detail)"
        case .responsePayloadMismatch(let operation, let detail):
            return "云端同步的 \(operation) 返回结构不符合当前同步上下文：\(detail)"
        case .requestEncodingFailed(let operation):
            return "云端同步暂时无法完成 \(operation) 的请求构造。"
        case .endpointNotImplemented(let operation):
            return "云端同步的 \(operation) 还没有接入请求实现。"
        }
    }
}

private protocol RealSyncRemoteAuthProviding: AnyObject {
    @MainActor
    func makeRealSyncAuthorization() -> RealSyncRemoteAuthorization?
}

private struct RealSyncRemoteAuthorization {
    let accountId: String
    let providerName: String
    let sessionSource: AccountSessionSource
    let bearerToken: String?
    let additionalHeaders: [String: String]
}

private enum RealSyncRemoteHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

private enum RealSyncRemoteEndpoint {
    case pushContent
    case pullContent
    case fetchRemoteSummary

    var operationName: String {
        switch self {
        case .pushContent:
            return "pushContent"
        case .pullContent:
            return "pullContent"
        case .fetchRemoteSummary:
            return "fetchRemoteSummary"
        }
    }

    var method: RealSyncRemoteHTTPMethod {
        switch self {
        case .pushContent:
            return .put
        case .pullContent, .fetchRemoteSummary:
            return .get
        }
    }

    func pathComponents(for context: AppSyncRequestContext) -> [String] {
        switch self {
        case .pushContent, .pullContent:
            return ["spaces", context.spaceId, "snapshot"]
        case .fetchRemoteSummary:
            return ["spaces", context.spaceId, "snapshot"]
        }
    }

    func queryItems(for context: AppSyncRequestContext) -> [URLQueryItem] {
        switch self {
        case .pushContent:
            return []
        case .pullContent, .fetchRemoteSummary:
            var items = [
                URLQueryItem(name: "accountId", value: context.accountId),
                URLQueryItem(name: "currentUserId", value: context.currentUserId)
            ]

            if let partnerUserId = context.partnerUserId, partnerUserId.isEmpty == false {
                items.append(URLQueryItem(name: "partnerUserId", value: partnerUserId))
            }

            return items
        }
    }
}

private struct RealSyncRemoteRequestBuilder {
    let configuration: RealSyncRemoteProviderConfiguration

    func makeRequest(
        endpoint: RealSyncRemoteEndpoint,
        context: AppSyncRequestContext,
        authorization: RealSyncRemoteAuthorization?,
        body: Data? = nil
    ) throws -> URLRequest {
        try makeRequest(
            method: endpoint.method,
            pathComponents: endpoint.pathComponents(for: context),
            queryItems: endpoint.queryItems(for: context),
            context: context,
            authorization: authorization,
            body: body,
            contentType: body == nil ? nil : "application/json"
        )
    }

    func makeRequest(
        method: RealSyncRemoteHTTPMethod,
        pathComponents: [String],
        queryItems: [URLQueryItem],
        context: AppSyncRequestContext,
        authorization: RealSyncRemoteAuthorization?,
        body: Data? = nil,
        contentType: String? = nil
    ) throws -> URLRequest {
        guard let baseURL = configuration.baseURL else {
            throw RealSyncRemoteProviderError.baseURLMissing
        }

        var url = baseURL
        for component in pathComponents {
            url.appendPathComponent(component)
        }

        if queryItems.isEmpty == false,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = queryItems
            if let resolvedURL = components.url {
                url = resolvedURL
            }
        }

        var request = URLRequest(url: url, timeoutInterval: configuration.timeoutInterval)
        request.httpMethod = method.rawValue

        for (header, value) in configuration.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        request.setValue(context.accountId, forHTTPHeaderField: "X-CoupleSpace-Account-ID")
        request.setValue(context.currentUserId, forHTTPHeaderField: "X-CoupleSpace-Current-User-ID")
        request.setValue(context.spaceId, forHTTPHeaderField: "X-CoupleSpace-Space-ID")

        if let partnerUserId = context.partnerUserId, partnerUserId.isEmpty == false {
            request.setValue(partnerUserId, forHTTPHeaderField: "X-CoupleSpace-Partner-User-ID")
        }

        if let authorization {
            request.setValue(authorization.accountId, forHTTPHeaderField: "X-CoupleSpace-Session-Account-ID")
            request.setValue(authorization.providerName, forHTTPHeaderField: "X-CoupleSpace-Provider-Name")
            request.setValue(authorization.sessionSource.rawValue, forHTTPHeaderField: "X-CoupleSpace-Session-Source")

            if let bearerToken = authorization.bearerToken,
               bearerToken.isEmpty == false {
                request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            }

            for (header, value) in authorization.additionalHeaders {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }

        if let body {
            request.httpBody = body
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        return request
    }
}

private struct RealSyncRemoteHTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, httpResponse)
    }

    func upload(_ request: URLRequest, from body: Data) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, httpResponse)
    }
}

private struct RealSyncRemotePullEnvelope: Decodable {
    let snapshot: RealSyncRemoteSnapshotResponse?
    let data: RealSyncRemoteSnapshotResponse?
    let payload: RealSyncRemoteSnapshotResponse?
    let content: RealSyncRemoteSnapshotResponse?

    var resolvedSnapshot: RealSyncRemoteSnapshotResponse? {
        snapshot ?? data ?? payload ?? content
    }
}

private struct RealSyncRemoteSnapshotResponse: Decodable {
    let snapshotId: String?
    let spaceId: String?
    let currentUserId: String?
    let partnerUserId: String?
    let isSharedSpace: Bool?
    let memories: [StoredRemoteMemory]
    let memoryTombstones: [StoredRemoteMemoryTombstone]
    let wishes: [StoredRemoteWish]
    let wishTombstones: [StoredRemoteWishTombstone]
    let anniversaries: [StoredRemoteAnniversary]
    let weeklyTodos: [StoredRemoteWeeklyTodo]
    let tonightDinners: [StoredRemoteTonightDinner]
    let rituals: [StoredRemoteRitual]
    let currentStatuses: [StoredRemoteCurrentStatus]
    let whisperNotes: [StoredRemoteWhisperNote]
    let relationStatusRawValue: String?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case snapshotId
        case id
        case scope
        case spaceId
        case currentUserId
        case partnerUserId
        case isSharedSpace
        case memories
        case memoryTombstones
        case wishes
        case wishTombstones
        case anniversaries
        case weeklyTodos
        case tonightDinners
        case rituals
        case currentStatuses
        case whisperNotes
        case relationStatusRawValue
        case relationStatus
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scope = try container.decodeIfPresent(StoredAppContentScope.self, forKey: .scope)

        snapshotId = try container.decodeIfPresent(String.self, forKey: .snapshotId)
            ?? (try container.decodeIfPresent(String.self, forKey: .id))
        spaceId = try container.decodeIfPresent(String.self, forKey: .spaceId) ?? scope?.spaceId
        currentUserId = try container.decodeIfPresent(String.self, forKey: .currentUserId) ?? scope?.currentUserId
        partnerUserId = try container.decodeIfPresent(String.self, forKey: .partnerUserId) ?? scope?.partnerUserId
        isSharedSpace = try container.decodeIfPresent(Bool.self, forKey: .isSharedSpace) ?? scope?.isSharedSpace
        memories = try container.decodeIfPresent([StoredRemoteMemory].self, forKey: .memories) ?? []
        memoryTombstones = try container.decodeIfPresent([StoredRemoteMemoryTombstone].self, forKey: .memoryTombstones) ?? []
        wishes = try container.decodeIfPresent([StoredRemoteWish].self, forKey: .wishes) ?? []
        wishTombstones = try container.decodeIfPresent([StoredRemoteWishTombstone].self, forKey: .wishTombstones) ?? []
        anniversaries = try container.decodeIfPresent([StoredRemoteAnniversary].self, forKey: .anniversaries) ?? []
        weeklyTodos = try container.decodeIfPresent([StoredRemoteWeeklyTodo].self, forKey: .weeklyTodos) ?? []
        tonightDinners = try container.decodeIfPresent([StoredRemoteTonightDinner].self, forKey: .tonightDinners) ?? []
        rituals = try container.decodeIfPresent([StoredRemoteRitual].self, forKey: .rituals) ?? []
        currentStatuses = try container.decodeIfPresent([StoredRemoteCurrentStatus].self, forKey: .currentStatuses) ?? []
        whisperNotes = try container.decodeIfPresent([StoredRemoteWhisperNote].self, forKey: .whisperNotes) ?? []
        relationStatusRawValue = try container.decodeIfPresent(String.self, forKey: .relationStatusRawValue)
            ?? container.decodeIfPresent(String.self, forKey: .relationStatus)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func remoteSnapshotPayload(
        for context: AppSyncRequestContext,
        fallbackSnapshotId: String?
    ) throws -> RemoteSyncSnapshotPayload {
        if let spaceId, spaceId != context.spaceId {
            throw RealSyncRemoteProviderError.responsePayloadMismatch(
                operation: RealSyncRemoteEndpoint.pullContent.operationName,
                detail: "spaceId 与当前请求不一致"
            )
        }

        if let currentUserId, currentUserId != context.currentUserId {
            throw RealSyncRemoteProviderError.responsePayloadMismatch(
                operation: RealSyncRemoteEndpoint.pullContent.operationName,
                detail: "currentUserId 与当前请求不一致"
            )
        }

        if let partnerUserId,
           let expectedPartnerUserId = context.partnerUserId,
           partnerUserId != expectedPartnerUserId {
            throw RealSyncRemoteProviderError.responsePayloadMismatch(
                operation: RealSyncRemoteEndpoint.pullContent.operationName,
                detail: "partnerUserId 与当前请求不一致"
            )
        }

        guard let updatedAt else {
            throw RealSyncRemoteProviderError.responseDecodingFailed(
                operation: RealSyncRemoteEndpoint.pullContent.operationName,
                detail: "缺少 updatedAt"
            )
        }

        let resolvedRelationRawValue = relationStatusRawValue ?? CoupleRelationStatus.unpaired.rawValue
        guard let relationStatus = CoupleRelationStatus(rawValue: resolvedRelationRawValue) else {
            throw RealSyncRemoteProviderError.responseDecodingFailed(
                operation: RealSyncRemoteEndpoint.pullContent.operationName,
                detail: "relationStatus 无法识别"
            )
        }

        let resolvedSnapshotId = snapshotId
            ?? fallbackSnapshotId
            ?? "remote-\(context.spaceId)-\(Int(updatedAt.timeIntervalSince1970))"

        return RemoteSyncSnapshotPayload(
            snapshotId: resolvedSnapshotId,
            spaceId: spaceId ?? context.spaceId,
            currentUserId: currentUserId ?? context.currentUserId,
            partnerUserId: partnerUserId ?? context.partnerUserId,
            isSharedSpace: isSharedSpace ?? (context.partnerUserId != nil),
            memories: memories.map(\.model),
            memoryTombstones: memoryTombstones.map(\.model),
            wishes: wishes.map(\.model),
            wishTombstones: wishTombstones.map(\.model),
            anniversaries: anniversaries.map(\.model),
            weeklyTodos: weeklyTodos.map(\.model),
            tonightDinners: tonightDinners.map(\.model),
            rituals: rituals.map(\.model),
            currentStatuses: currentStatuses.map(\.model),
            whisperNotes: whisperNotes.map(\.model),
            relationStatus: relationStatus,
            updatedAt: updatedAt
        )
    }
}

struct UploadedMemoryAssetReference: Equatable {
    let assetId: String
    let memoryId: String
    let spaceId: String
    let storageKey: String
    let mimeType: String
    let byteSize: Int
    let checksum: String?
    let createdAt: Date
    let uploadedByUserId: String
}

private struct RealSyncRemoteMemoryAssetUploadResponse: Decodable {
    let assetId: String
    let memoryId: String
    let spaceId: String
    let storageKey: String
    let mimeType: String
    let byteSize: Int
    let checksum: String?
    let createdAt: Date
    let uploadedByUserId: String

    func uploadedReference() -> UploadedMemoryAssetReference {
        UploadedMemoryAssetReference(
            assetId: assetId,
            memoryId: memoryId,
            spaceId: spaceId,
            storageKey: storageKey,
            mimeType: mimeType,
            byteSize: byteSize,
            checksum: checksum,
            createdAt: createdAt,
            uploadedByUserId: uploadedByUserId
        )
    }
}

// 未来真实同步远端实现正式落位在这里。
// 真正开始接 API 时，优先只补这三个协议方法，不改 UI / AppSyncService 主流程。
struct RealSyncRemoteProvider: AppSyncRemoteProviding {
    let providerKind: AppSyncRemoteProviderKind = .productionReal
    let providerName: String
    let availability: SyncRemoteAvailability = .placeholder

    private let configuration: RealSyncRemoteProviderConfiguration
    private let requestBuilder: RealSyncRemoteRequestBuilder
    private let httpClient: RealSyncRemoteHTTPClient
    private let authProvider: (any RealSyncRemoteAuthProviding)?

    fileprivate init(
        configuration: RealSyncRemoteProviderConfiguration = .current,
        accountSessionStore: AccountSessionStore? = nil,
        httpClient: RealSyncRemoteHTTPClient = RealSyncRemoteHTTPClient()
    ) {
        self.configuration = configuration
        self.providerName = configuration.providerName
        self.requestBuilder = RealSyncRemoteRequestBuilder(configuration: configuration)
        self.httpClient = httpClient
        self.authProvider = accountSessionStore
    }

    func pushContent(_ payload: SyncContentPayload, context: AppSyncRequestContext) async throws {
        let requestBody = try makePushRequestBody(payload)
        let endpoint = RealSyncRemoteEndpoint.pushContent
        let request = try await makePreparedRequest(
            endpoint: endpoint,
            context: context,
            body: requestBody
        )
        let responseData: Data
        let response: HTTPURLResponse

        do {
            (responseData, response) = try await httpClient.execute(request)
        } catch {
            throw mapRequestFailure(error, operation: endpoint.operationName)
        }

        try validateResponseStatus(response, data: responseData, endpoint: endpoint)
    }

    func pullContent(for context: AppSyncRequestContext) async throws -> SyncContentPayload {
        let endpoint = RealSyncRemoteEndpoint.pullContent
        let request = try await makePreparedRequest(endpoint: endpoint, context: context)
        let responseData: Data
        let response: HTTPURLResponse

        do {
            (responseData, response) = try await httpClient.execute(request)
        } catch {
            throw mapRequestFailure(error, operation: endpoint.operationName)
        }

        try validateResponseStatus(response, data: responseData, endpoint: endpoint)
        let remoteSnapshot = try decodePullSnapshotPayload(
            from: responseData,
            response: response,
            context: context
        )
        return .fromRemoteSnapshotPayload(remoteSnapshot)
    }

    func fetchRemoteSummary(for context: AppSyncRequestContext) async throws -> SyncRemotePayloadSummary? {
        _ = try await makePreparedRequest(endpoint: .fetchRemoteSummary, context: context)
        throw RealSyncRemoteProviderError.endpointNotImplemented(operation: "fetchRemoteSummary")
    }

    func uploadMemoryAsset(
        data: Data,
        mimeType: String,
        memoryID: UUID,
        context: AppSyncRequestContext
    ) async throws -> UploadedMemoryAssetReference {
        try validateConfiguration(for: context)
        let authorization = try await resolveAuthorization(for: context)
        debugMemoryAssetSync(
            "prepare upload request memory=\(memoryID.uuidString.lowercased()) space=\(context.spaceId) bytes=\(data.count) mime=\(mimeType) account=\(context.accountId)"
        )
        var request = try requestBuilder.makeRequest(
            method: .post,
            pathComponents: ["spaces", context.spaceId, "memory-assets"],
            queryItems: [URLQueryItem(name: "memoryId", value: memoryID.uuidString.lowercased())],
            context: context,
            authorization: authorization,
            body: nil,
            contentType: nil
        )
        request.timeoutInterval = max(request.timeoutInterval, 120)
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")

        let responseData: Data
        let response: HTTPURLResponse

        do {
            (responseData, response) = try await httpClient.upload(request, from: data)
        } catch is CancellationError {
            debugMemoryAssetSync("upload request cancelled memory=\(memoryID.uuidString.lowercased())")
            throw RealSyncRemoteProviderError.requestFailed(
                operation: "uploadMemoryAsset",
                detail: "上传任务在发送过程中被取消了"
            )
        } catch let urlError as URLError where urlError.code == .cancelled {
            debugMemoryAssetSync("upload request cancelled memory=\(memoryID.uuidString.lowercased()) urlError=cancelled")
            throw RealSyncRemoteProviderError.requestFailed(
                operation: "uploadMemoryAsset",
                detail: "上传任务在发送过程中被取消了"
            )
        } catch let urlError as URLError {
            debugMemoryAssetSync(
                "upload request urlError memory=\(memoryID.uuidString.lowercased()) code=\(urlError.code.rawValue) detail=\(urlError.localizedDescription)"
            )
            throw mapRequestFailure(urlError, operation: "uploadMemoryAsset")
        } catch {
            debugMemoryAssetSync("upload request failed memory=\(memoryID.uuidString.lowercased()) error=\(error.localizedDescription)")
            throw mapRequestFailure(error, operation: "uploadMemoryAsset")
        }

        debugMemoryAssetSync(
            "upload response received memory=\(memoryID.uuidString.lowercased()) status=\(response.statusCode) bytes=\(responseData.count)"
        )

        guard (200...299).contains(response.statusCode) else {
            debugMemoryAssetSync(
                "upload response unexpected memory=\(memoryID.uuidString.lowercased()) status=\(response.statusCode) body=\(responseBodyPreview(from: responseData) ?? "nil")"
            )
            throw RealSyncRemoteProviderError.unexpectedStatusCode(
                operation: "uploadMemoryAsset",
                statusCode: response.statusCode,
                responseBody: responseBodyPreview(from: responseData)
            )
        }

        let decoder = makeSyncJSONDecoder()

        do {
            let payload = try decoder.decode(RealSyncRemoteMemoryAssetUploadResponse.self, from: responseData)
            debugMemoryAssetSync("upload response success memory=\(payload.memoryId) asset=\(payload.assetId) space=\(payload.spaceId)")
            return payload.uploadedReference()
        } catch {
            debugMemoryAssetSync("upload response decode failed memory=\(memoryID.uuidString.lowercased()) error=\(error.localizedDescription)")
            throw RealSyncRemoteProviderError.responseDecodingFailed(
                operation: "uploadMemoryAsset",
                detail: error.localizedDescription
            )
        }
    }

    private func validateConfiguration(for context: AppSyncRequestContext) throws {
        guard configuration.baseURL != nil else {
            throw RealSyncRemoteProviderError.baseURLMissing
        }

        if configuration.requiresAuthenticatedSession, context.accountId.isEmpty {
            throw RealSyncRemoteProviderError.authenticatedSessionRequired
        }
    }

    private func makePushRequestBody(_ payload: SyncContentPayload) throws -> Data {
        let encoder = makeSyncJSONEncoder()

        do {
            debugWhisperSync("encode push payload space=\(payload.scope.spaceId) whisperNotes=\(payload.whisperNotes.count)")
            debugWishSync(
                "encode push payload space=\(payload.scope.spaceId) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
            )
            return try encoder.encode(StoredRemotePayload(payload: payload))
        } catch {
            throw RealSyncRemoteProviderError.requestEncodingFailed(operation: "pushContent")
        }
    }

    private func makePreparedRequest(
        endpoint: RealSyncRemoteEndpoint,
        context: AppSyncRequestContext,
        body: Data? = nil
    ) async throws -> URLRequest {
        try validateConfiguration(for: context)
        let authorization = try await resolveAuthorization(for: context)
        return try requestBuilder.makeRequest(
            endpoint: endpoint,
            context: context,
            authorization: authorization,
            body: body
        )
    }

    private func resolveAuthorization(
        for context: AppSyncRequestContext
    ) async throws -> RealSyncRemoteAuthorization? {
        if configuration.requiresAuthenticatedSession, authProvider == nil {
            throw RealSyncRemoteProviderError.authorizationSourceMissing
        }

        let authorization = await authProvider?.makeRealSyncAuthorization()

        if configuration.requiresAuthenticatedSession {
            guard let authorization, authorization.sessionSource == .authenticated else {
                throw RealSyncRemoteProviderError.authenticatedSessionRequired
            }

            guard authorization.accountId == context.accountId else {
                throw RealSyncRemoteProviderError.authenticatedSessionRequired
            }

            return authorization
        }

        return authorization
    }

    private func validateResponseStatus(
        _ response: HTTPURLResponse,
        data: Data,
        endpoint: RealSyncRemoteEndpoint
    ) throws {
        guard (200...299).contains(response.statusCode) else {
            throw RealSyncRemoteProviderError.unexpectedStatusCode(
                operation: endpoint.operationName,
                statusCode: response.statusCode,
                responseBody: responseBodyPreview(from: data)
            )
        }
    }

    private func decodePullSnapshotPayload(
        from data: Data,
        response: HTTPURLResponse,
        context: AppSyncRequestContext
    ) throws -> RemoteSyncSnapshotPayload {
        let decoder = makeSyncJSONDecoder()

        if let envelope = try? decoder.decode(RealSyncRemotePullEnvelope.self, from: data),
           let snapshot = envelope.resolvedSnapshot {
            let payload = try snapshot.remoteSnapshotPayload(
                for: context,
                fallbackSnapshotId: responseSnapshotIdentifier(from: response)
            )
            debugWhisperSync("decode pull payload space=\(payload.spaceId) whisperNotes=\(payload.whisperNotes.count)")
            debugWishSync(
                "decode pull payload space=\(payload.spaceId) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones)) updatedAt=\(payload.updatedAt.timeIntervalSince1970)"
            )
            return payload
        }

        do {
            let snapshot = try decoder.decode(RealSyncRemoteSnapshotResponse.self, from: data)
            let payload = try snapshot.remoteSnapshotPayload(
                for: context,
                fallbackSnapshotId: responseSnapshotIdentifier(from: response)
            )
            debugWhisperSync("decode pull payload space=\(payload.spaceId) whisperNotes=\(payload.whisperNotes.count)")
            debugWishSync(
                "decode pull payload space=\(payload.spaceId) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones)) updatedAt=\(payload.updatedAt.timeIntervalSince1970)"
            )
            return payload
        } catch let providerError as RealSyncRemoteProviderError {
            throw providerError
        } catch {
            throw RealSyncRemoteProviderError.responseDecodingFailed(
                operation: RealSyncRemoteEndpoint.pullContent.operationName,
                detail: error.localizedDescription
            )
        }
    }

    private func responseSnapshotIdentifier(from response: HTTPURLResponse) -> String? {
        response.value(forHTTPHeaderField: "X-CoupleSpace-Snapshot-ID")
            ?? response.value(forHTTPHeaderField: "ETag")
    }

    private func mapRequestFailure(
        _ error: Error,
        operation: String
    ) -> RealSyncRemoteProviderError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .timedOut, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return .backendUnavailable(operation: operation)
            default:
                break
            }
        }

        return .requestFailed(
            operation: operation,
            detail: error.localizedDescription
        )
    }

    private func responseBodyPreview(from data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            return nil
        }

        let preview = text.prefix(160)
        return String(preview)
    }
}

// 演示阶段的假远端实现。
// 下一轮接真实后端时，优先保持 AppSyncService 和 UI 不动，只替换这里的 provider 注入。
final class FakeSyncRemoteProvider: AppSyncRemoteProviding {
    let providerKind: AppSyncRemoteProviderKind = .demoFakeRemote
    let providerName = "内置云端环境"
    let availability: SyncRemoteAvailability = .connected

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.fakeRemotePayloads"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pushContent(_ payload: SyncContentPayload, context: AppSyncRequestContext) async throws {
        var records = loadRecords()
        records[storageIdentifier(for: context)] = StoredRemotePayload(payload: payload)
        try saveRecords(records)
    }

    func pullContent(for context: AppSyncRequestContext) async throws -> SyncContentPayload {
        let records = loadRecords()
        guard let record = records[storageIdentifier(for: context)] else {
            throw AppSyncPrototypeError.remoteContentMissing
        }
        return record.model
    }

    func fetchRemoteSummary(for context: AppSyncRequestContext) async throws -> SyncRemotePayloadSummary? {
        let records = loadRecords()
        return records[storageIdentifier(for: context)]?.summary
    }

    private func storageIdentifier(for context: AppSyncRequestContext) -> String {
        "\(context.accountId)::\(context.spaceId)"
    }

    private func loadRecords() -> [String: StoredRemotePayload] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        do {
            let decoder = makeSyncJSONDecoder()
            return try decoder.decode([String: StoredRemotePayload].self, from: data)
        } catch {
            defaults.removeObject(forKey: storageKey)
            return [:]
        }
    }

    private func saveRecords(_ records: [String: StoredRemotePayload]) throws {
        let encoder = makeSyncJSONEncoder()
        let data = try encoder.encode(records)
        defaults.set(data, forKey: storageKey)
    }
}

@MainActor
final class AccountSessionStore: ObservableObject {
    @Published private(set) var state: AccountSessionState

    private let defaults: UserDefaults
    private let storageKey = "com.barry.CoupleSpace.accountSession"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: storageKey) {
            do {
                let decoder = makeSyncJSONDecoder()
                state = try decoder.decode(AccountSessionState.self, from: data)
                return
            } catch {
                defaults.removeObject(forKey: storageKey)
            }
        }

        state = .localDefault
    }

    func prepareDemoSession(currentNickname: String) {
        let nickname = currentNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = nickname.isEmpty ? "我" : nickname
        let preparedAt = Date()

        state = AccountSessionState(
            account: AccountProfile(
                accountId: "acct-demo-\(resolvedName.lowercased())",
                nickname: resolvedName,
                providerName: "余白",
                detailText: "云端准备状态"
            ),
            authorization: nil,
            sessionSource: .demo,
            cloudMode: .prepared,
            lastPreparedAt: preparedAt
        )
        save()
    }

    // Future hook:
    // 真实登录落地时，优先从这里接服务端 account profile。
    // UI 和 AppSyncService 继续只读取 session state，不需要一起重写。
    func adoptAuthenticatedSession(
        profile: AccountProfile,
        authorization: AccountSessionAuthorization? = nil,
        cloudMode: AccountCloudMode = .enabled
    ) {
        state = AccountSessionState(
            account: profile,
            authorization: authorization,
            sessionSource: .authenticated,
            cloudMode: cloudMode,
            lastPreparedAt: .now
        )
        save()
    }

    // Future login handoff:
    // 真实登录 API 接通后，先把返回结果整理成 AuthenticatedAccountPayload，
    // 再从这里进入本地 session，避免 UI / store 直接依赖后端返回结构。
    func adoptAuthenticatedPayload(
        _ payload: AuthenticatedAccountPayload,
        authorization: AccountSessionAuthorization? = nil,
        cloudMode: AccountCloudMode = .enabled
    ) {
        adoptAuthenticatedSession(
            profile: .fromAuthenticatedPayload(payload),
            authorization: authorization ?? AccountSessionAuthorization.fromAuthenticatedPayload(payload),
            cloudMode: cloudMode
        )
    }

    func clearSession() {
        state = .localDefault
        save()
    }

    private func save() {
        do {
            let encoder = makeSyncJSONEncoder()
            let data = try encoder.encode(state)
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save account session: \(error)")
        }
    }
}

extension AccountSessionStore: RealSyncRemoteAuthProviding {
    @MainActor
    fileprivate func makeRealSyncAuthorization() -> RealSyncRemoteAuthorization? {
        guard let account = state.account else {
            return nil
        }

        return RealSyncRemoteAuthorization(
            accountId: account.accountId,
            providerName: account.providerName,
            sessionSource: state.sessionSource,
            bearerToken: state.authorization?.accessToken,
            additionalHeaders: [:]
        )
    }
}

@MainActor
final class AppSyncService: ObservableObject {
    @Published private(set) var status: SyncStatusSnapshot

    private static let pendingAutomaticPushDefaultsKey = "com.barry.CoupleSpace.pendingAutomaticPush"
    private let sessionStore: AccountSessionStore
    private let relationshipStore: RelationshipStore
    // 这里保留为稳定的同步编排层：
    // 未来切真实后端时，只替换 remote provider，不把 UI 直接改成请求 API。
    private let remoteProvider: AppSyncRemoteProviding
    private lazy var realSyncProvider = RealSyncRemoteProvider(accountSessionStore: sessionStore)
    private let localBackendAccountLoginClient: LocalBackendAccountLoginClient
    private let localBackendDemoLoginClient: LocalBackendDemoLoginClient
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var remoteSummary: SyncRemotePayloadSummary?
    private var isSyncing = false
    private var latestPulledPayload: SyncContentPayload?
    private var lastPushAt: Date?
    private var lastPushedSnapshotUpdatedAt: Date?
    private var lastPullAt: Date?
    private var lastAppliedAt: Date?
    private var lastAppliedRemoteUpdatedAt: Date?
    private var lastDeferredRemoteUpdatedAt: Date?
    private var latestEventText: String?
    private var latestErrorText: String?
    private var automaticPushTask: Task<Void, Never>?
    private var automaticPullTask: Task<Void, Never>?
    private var deferredAutomaticApplyTask: Task<Void, Never>?
    private var postPushConvergencePullTask: Task<Void, Never>?
    private var memoryAssetUploadTasks: [UUID: Task<Void, Never>] = [:]
    private var latestAutomaticPushSignature: String?
    private var lastAutomaticPullAt: Date?
    private var automaticPushSuppressedUntil: Date?
    private var lastLocalSharedContentMutationAt: Date?
    private var isApplyingLatestPulledContent = false
    private let automaticPushDebounceNanoseconds: UInt64 = 1_500_000_000
    private let automaticPullMinimumInterval: TimeInterval = 6
    private let automaticPullHeartbeatInterval: TimeInterval = 6
    private let automaticApplyLocalMutationCooldown: TimeInterval = 8
    private let automaticApplyRecentPushCooldown: TimeInterval = 6
    private let postPushConvergencePullDelay: TimeInterval = 6.5

    init(
        sessionStore: AccountSessionStore,
        relationshipStore: RelationshipStore,
        remoteProvider: AppSyncRemoteProviding = FakeSyncRemoteProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.sessionStore = sessionStore
        self.relationshipStore = relationshipStore
        self.remoteProvider = remoteProvider
        self.localBackendAccountLoginClient = LocalBackendAccountLoginClient()
        self.localBackendDemoLoginClient = LocalBackendDemoLoginClient()
        self.defaults = defaults
        self.status = Self.makeStatus(
            session: sessionStore.state,
            relationship: relationshipStore.state,
            remoteProvider: remoteProvider,
            remoteSummary: nil,
            isSyncing: false,
            latestPulledPayload: nil,
            lastPushAt: nil,
            lastPullAt: nil,
            lastAppliedAt: nil,
            lastAppliedRemoteUpdatedAt: nil,
            latestEventText: nil,
            latestErrorText: nil
        )

        Publishers.CombineLatest(sessionStore.$state, relationshipStore.$state)
            .receive(on: RunLoop.main)
            .sink { [weak self] session, relationship in
                self?.publishStatus(session: session, relationship: relationship)
            }
            .store(in: &cancellables)
    }

    func prepareCloudSession(using nickname: String) {
        sessionStore.prepareDemoSession(currentNickname: nickname)
    }

    // 演练未来真实登录接入：
    // 用本地 mock 的 AuthenticatedAccountPayload 显式走一次 session 承接路径，
    // 验证 UI / 同步状态都能读到 authenticated 结果。
    func rehearseAuthenticatedSession(
        with payload: AuthenticatedAccountPayload,
        cloudMode: AccountCloudMode = .enabled
    ) {
        sessionStore.adoptAuthenticatedPayload(payload, cloudMode: cloudMode)
        latestErrorText = nil
        latestEventText = "已承接一份真实登录结果演练返回"
        publishStatus()
    }

    func loginWithBackend(email: String, password: String) async throws {
        isSyncing = true
        latestErrorText = nil
        latestEventText = "正在登录账号"
        publishStatus()

        do {
            let payload = try await localBackendAccountLoginClient.login(email: email, password: password)
            sessionStore.adoptAuthenticatedPayload(payload)
            latestErrorText = nil
            latestEventText = "已登录 \(payload.displayName)，当前会话会继续沿用这份账号"
            isSyncing = false
            publishStatus()
        } catch {
            latestErrorText = error.localizedDescription
            latestEventText = "这次没有登录成功"
            isSyncing = false
            publishStatus()
            throw error
        }
    }

    func connectLocalBackendDemoAccount() async {
        isSyncing = true
        latestErrorText = nil
        latestEventText = "正在连接测试环境账号"
        publishStatus()

        do {
            let payload = try await localBackendDemoLoginClient.login()
            sessionStore.adoptAuthenticatedPayload(payload)
            latestErrorText = nil
            latestEventText = "已连接测试环境账号，并承接了当前所需的鉴权信息"
            isSyncing = false
            publishStatus()
        } catch {
            latestErrorText = error.localizedDescription
            latestEventText = "这次没有连接上测试环境账号"
            isSyncing = false
            publishStatus()
        }
    }

    func returnToLocalMode() {
        automaticPushTask?.cancel()
        automaticPullTask?.cancel()
        deferredAutomaticApplyTask?.cancel()
        postPushConvergencePullTask?.cancel()
        latestAutomaticPushSignature = nil
        lastAutomaticPullAt = nil
        automaticPushSuppressedUntil = nil
        lastLocalSharedContentMutationAt = nil
        lastPushedSnapshotUpdatedAt = nil
        lastAppliedRemoteUpdatedAt = nil
        lastDeferredRemoteUpdatedAt = nil
        markPendingAutomaticPush(false)
        sessionStore.clearSession()
        remoteSummary = nil
        latestPulledPayload = nil
        latestEventText = "已回到本地模式"
        latestErrorText = nil
        publishStatus()
    }

    @discardableResult
    func uploadMemoryPhotoIfPossible(
        for entry: MemoryTimelineEntry,
        scope: AppContentScope,
        memoryStore: MemoryStore
    ) async -> UploadedMemoryAssetReference? {
        debugMemoryAssetSync(
            "trigger upload check entry=\(entry.id.uuidString.lowercased()) photo=\(entry.photoFilename ?? "nil") remoteAsset=\(entry.remoteAssetID ?? "nil") scope=\(scope.spaceId)"
        )
        guard canAttemptAutomaticBackendSync(for: scope) else {
            debugMemoryAssetSync("skip upload entry=\(entry.id.uuidString.lowercased()) reason=backend sync unavailable")
            return nil
        }
        guard let photoFilename = entry.photoFilename,
              photoFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            debugMemoryAssetSync("skip upload entry=\(entry.id.uuidString.lowercased()) reason=missing photoFilename")
            return nil
        }

        guard entry.remoteAssetID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            debugMemoryAssetSync("skip upload entry=\(entry.id.uuidString.lowercased()) reason=remoteAsset already exists")
            return nil
        }

        guard let originalImageData = MemoryPhotoStorage.imageData(for: photoFilename) else {
            debugMemoryAssetSync("skip upload entry=\(entry.id.uuidString.lowercased()) reason=failed to read image data")
            latestErrorText = "这条记忆的本地图片暂时读取失败，无法上传到测试环境。"
            latestEventText = "记忆图片上传没有成功"
            publishStatus()
            return nil
        }
        guard let imageData = MemoryPhotoStorage.uploadImageData(for: photoFilename) else {
            debugMemoryAssetSync("skip upload entry=\(entry.id.uuidString.lowercased()) reason=failed to prepare upload data")
            latestErrorText = "这条记忆的图片暂时没有整理成可上传格式，请稍后重试。"
            latestEventText = "记忆图片上传没有成功"
            publishStatus()
            return nil
        }
        debugMemoryAssetSync(
            "image data ready entry=\(entry.id.uuidString.lowercased()) originalBytes=\(originalImageData.count) uploadBytes=\(imageData.count)"
        )

        do {
            let target = try await resolveManualBackendSyncTarget(preferredScope: scope)
            debugMemoryAssetSync(
                "call uploadMemoryAsset entry=\(entry.id.uuidString.lowercased()) account=\(target.context.accountId) currentUser=\(target.context.currentUserId) space=\(target.context.spaceId)"
            )
            let uploadedAsset = try await realSyncProvider.uploadMemoryAsset(
                data: imageData,
                mimeType: "image/jpeg",
                memoryID: entry.id,
                context: target.context
            )
            memoryStore.setRemoteAssetID(uploadedAsset.assetId, for: entry.id, in: target.scope)
            debugMemoryAssetSync("upload finished entry=\(entry.id.uuidString.lowercased()) asset=\(uploadedAsset.assetId)")
            latestErrorText = nil
            latestEventText = "已为这条记忆上传图片资源（assetId: \(uploadedAsset.assetId)）"
            publishStatus()
            return uploadedAsset
        } catch {
            debugMemoryAssetSync("upload failed entry=\(entry.id.uuidString.lowercased()) error=\(error.localizedDescription)")
            latestErrorText = error.localizedDescription
            latestEventText = "记忆图片上传没有成功"
            publishStatus()
            return nil
        }
    }

    func scheduleMemoryPhotoUploadIfPossible(
        for entry: MemoryTimelineEntry,
        scope: AppContentScope,
        memoryStore: MemoryStore
    ) {
        let entryID = entry.id
        if let existingTask = memoryAssetUploadTasks[entryID] {
            existingTask.cancel()
            debugMemoryAssetSync("cancel existing scheduled upload entry=\(entryID.uuidString.lowercased())")
        }

        debugMemoryAssetSync(
            "schedule upload task entry=\(entryID.uuidString.lowercased()) photo=\(entry.photoFilename ?? "nil") scope=\(scope.spaceId)"
        )

        memoryAssetUploadTasks[entryID] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.memoryAssetUploadTasks[entryID] = nil
                debugMemoryAssetSync("upload task cleared entry=\(entryID.uuidString.lowercased())")
            }

            guard Task.isCancelled == false else {
                debugMemoryAssetSync("scheduled upload task cancelled before start entry=\(entryID.uuidString.lowercased())")
                return
            }

            _ = await self.uploadMemoryPhotoIfPossible(
                for: entry,
                scope: scope,
                memoryStore: memoryStore
            )
        }
    }

    func scheduleAutomaticPushIfPossible(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        scope: AppContentScope,
        trigger: AutomaticSyncTrigger
    ) {
        guard canAttemptAutomaticBackendSync(for: scope) else {
            debugAutomaticPush("schedule skipped trigger=\(trigger.rawValue) reason=backend sync unavailable")
            return
        }
        guard isApplyingLatestPulledContent == false else {
            debugAutomaticPush("schedule skipped trigger=\(trigger.rawValue) reason=applying pulled content")
            debugWishSync("schedule push skipped trigger=\(trigger.rawValue) scope=\(scope.spaceId) reason=applying pulled content")
            return
        }
        postPushConvergencePullTask?.cancel()
        postPushConvergencePullTask = nil
        deferredAutomaticApplyTask?.cancel()
        deferredAutomaticApplyTask = nil
        lastLocalSharedContentMutationAt = .now
        markPendingAutomaticPush(true)

        let signature = automaticPushSignature(
            memories: memories,
            memoryTombstones: memoryTombstones,
            wishes: wishes,
            wishTombstones: wishTombstones,
            anniversaries: anniversaries,
            weeklyTodos: weeklyTodos,
            tonightDinners: tonightDinners,
            rituals: rituals,
            currentStatuses: currentStatuses,
            whisperNotes: whisperNotes,
            scope: scope
        )

        debugAutomaticPush(
            "schedule automatic push trigger=\(trigger.rawValue) signature=\(signature) memories=\(memories.count) memoryTombstones=\(memoryTombstones.count) wishes=\(wishes.count) weeklyTodos=\(weeklyTodos.count)"
        )
        debugMemorySync(
            "schedule push trigger=\(trigger.rawValue) scope=\(scope.spaceId) memories=\(memoryDebugSummary(memories)) tombstones=\(memoryTombstoneDebugSummary(memoryTombstones))"
        )
        debugWishSync(
            "schedule push trigger=\(trigger.rawValue) scope=\(scope.spaceId) wishes=\(wishDebugSummary(wishes)) tombstones=\(wishTombstoneDebugSummary(wishTombstones))"
        )
        if automaticPushTask != nil {
            debugAutomaticPush("schedule automatic push replacing existing task trigger=\(trigger.rawValue)")
        }
        automaticPushTask?.cancel()
        automaticPushTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: self.automaticPushDebounceNanoseconds)
            } catch {
                debugAutomaticPush("automatic push task cancelled during debounce trigger=\(trigger.rawValue)")
                return
            }

            guard !Task.isCancelled else {
                debugAutomaticPush("automatic push task cancelled before execution trigger=\(trigger.rawValue)")
                return
            }
            guard self.canAttemptAutomaticBackendSync(for: scope) else {
                debugAutomaticPush("delayed push skipped trigger=\(trigger.rawValue) reason=backend sync unavailable")
                return
            }
            while let suppressedUntil = self.automaticPushSuppressedUntil, suppressedUntil > .now {
                let remainingSeconds = suppressedUntil.timeIntervalSinceNow
                guard remainingSeconds > 0 else { break }
                debugAutomaticPush(
                    "delayed by suppression window trigger=\(trigger.rawValue) remaining=\(String(format: "%.2f", remainingSeconds))s"
                )
                let remainingNanoseconds = UInt64((remainingSeconds * 1_000_000_000).rounded(.up))
                do {
                    try await Task.sleep(nanoseconds: remainingNanoseconds)
                } catch {
                    debugAutomaticPush("automatic push task cancelled while waiting suppression trigger=\(trigger.rawValue)")
                    return
                }
                guard !Task.isCancelled else {
                    debugAutomaticPush("automatic push task cancelled after suppression wait trigger=\(trigger.rawValue)")
                    return
                }
            }
            debugAutomaticPush("suppression window ended trigger=\(trigger.rawValue)")
            while self.isSyncing {
                debugAutomaticPush("delayed push waiting because sync still running trigger=\(trigger.rawValue)")
                debugWishSync("delayed push waiting trigger=\(trigger.rawValue) scope=\(scope.spaceId) isSyncing=true")
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    debugAutomaticPush("automatic push task cancelled while waiting active sync trigger=\(trigger.rawValue)")
                    return
                }
                guard !Task.isCancelled else {
                    debugAutomaticPush("automatic push task cancelled after waiting active sync trigger=\(trigger.rawValue)")
                    return
                }
                guard self.canAttemptAutomaticBackendSync(for: scope) else {
                    debugAutomaticPush("delayed push skipped after wait trigger=\(trigger.rawValue) reason=backend sync unavailable")
                    return
                }
            }
            guard self.latestAutomaticPushSignature != signature else {
                debugAutomaticPush("delayed push skipped because signature already synced trigger=\(trigger.rawValue)")
                self.markPendingAutomaticPush(false)
                return
            }
            debugAutomaticPush("performing delayed push trigger=\(trigger.rawValue) signature=\(signature)")
            debugMemorySync(
                "perform push trigger=\(trigger.rawValue) scope=\(scope.spaceId) memories=\(self.memoryDebugSummary(memories)) tombstones=\(self.memoryTombstoneDebugSummary(memoryTombstones))"
            )
            debugWishSync(
                "perform push trigger=\(trigger.rawValue) scope=\(scope.spaceId) wishes=\(self.wishDebugSummary(wishes)) tombstones=\(self.wishTombstoneDebugSummary(wishTombstones))"
            )

            let didPush = await self.pushCurrentScopeContentToLocalBackend(
                memories: memories,
                memoryTombstones: memoryTombstones,
                wishes: wishes,
                wishTombstones: wishTombstones,
                anniversaries: anniversaries,
                weeklyTodos: weeklyTodos,
                tonightDinners: tonightDinners,
                rituals: rituals,
                currentStatuses: currentStatuses,
                whisperNotes: whisperNotes,
                scope: scope,
                eventTextOverride: trigger.automaticPushEventText,
                shouldRecordErrors: false
            )

            guard didPush else {
                debugAutomaticPush("delayed push finished trigger=\(trigger.rawValue) result=failed")
                debugMemorySync("push failed trigger=\(trigger.rawValue) scope=\(scope.spaceId)")
                debugWishSync("push failed trigger=\(trigger.rawValue) scope=\(scope.spaceId)")
                return
            }
            self.latestAutomaticPushSignature = signature
            self.markPendingAutomaticPush(false)
            debugAutomaticPush("delayed push finished trigger=\(trigger.rawValue) result=success")
            debugMemorySync("push finished trigger=\(trigger.rawValue) scope=\(scope.spaceId) result=success")
            debugWishSync("push finished trigger=\(trigger.rawValue) scope=\(scope.spaceId) result=success")
        }
    }

    @discardableResult
    func resumePendingAutomaticPushIfPossible(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        scope: AppContentScope,
        trigger: AutomaticSyncTrigger = .appBecameActive
    ) -> Bool {
        guard hasPendingAutomaticPush else {
            debugAutomaticPush("resume skipped trigger=\(trigger.rawValue) reason=no pending push")
            return false
        }
        debugAutomaticPush("resume pending automatic push trigger=\(trigger.rawValue)")
        scheduleAutomaticPushIfPossible(
            memories: memories,
            memoryTombstones: memoryTombstones,
            wishes: wishes,
            wishTombstones: wishTombstones,
            anniversaries: anniversaries,
            weeklyTodos: weeklyTodos,
            tonightDinners: tonightDinners,
            rituals: rituals,
            currentStatuses: currentStatuses,
            whisperNotes: whisperNotes,
            scope: scope,
            trigger: trigger
        )
        return true
    }

    func scheduleAutomaticPullIfPossible(
        scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore,
        trigger: AutomaticSyncTrigger
    ) {
        guard canAttemptAutomaticBackendSync(for: scope) else { return }
        guard isSyncing == false else { return }
        if let lastAutomaticPullAt, Date().timeIntervalSince(lastAutomaticPullAt) < automaticPullMinimumInterval {
            return
        }

        let shouldSurfaceActivity = trigger != .foregroundHeartbeat

        automaticPullTask?.cancel()
        automaticPullTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.canAttemptAutomaticBackendSync(for: scope) else { return }
            guard self.isSyncing == false else { return }

            self.lastAutomaticPullAt = .now
            guard let payload = await self.pullCurrentScopeContentFromLocalBackend(
                scope: scope,
                eventTextOverride: shouldSurfaceActivity ? trigger.automaticPullEventText : nil,
                shouldRecordErrors: false,
                shouldSurfaceActivity: shouldSurfaceActivity
            ) else {
                return
            }

            if let staleReason = self.hardStaleReasonForAutomaticApply(payload) {
                debugAutomaticPush(
                    "automatic pull payload marked stale trigger=\(trigger.rawValue) reason=\(staleReason)"
                )
                debugMemorySync(
                    "pull stale trigger=\(trigger.rawValue) reason=\(staleReason) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) memories=\(self.memoryDebugSummary(payload.memories)) tombstones=\(self.memoryTombstoneDebugSummary(payload.memoryTombstones))"
                )
                debugWishSync(
                    "pull stale trigger=\(trigger.rawValue) reason=\(staleReason) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(self.wishDebugSummary(payload.wishes)) tombstones=\(self.wishTombstoneDebugSummary(payload.wishTombstones))"
                )
                if self.latestPulledPayload?.updatedAt == payload.updatedAt {
                    self.latestPulledPayload = nil
                }
                self.lastDeferredRemoteUpdatedAt = nil
                return
            }

            let autoApplyDelay = self.automaticApplyDelayIfPossible(
                for: payload,
                into: scope
            )

            guard let autoApplyDelay else {
                self.notePendingPulledContentIfNeeded(payload, trigger: trigger)
                return
            }

            if autoApplyDelay > 0 {
                self.notePendingPulledContentIfNeeded(payload, trigger: trigger)
                self.scheduleDeferredAutomaticApplyIfPossible(
                    after: autoApplyDelay,
                    payload: payload,
                    scope: scope,
                    memoryStore: memoryStore,
                    wishStore: wishStore,
                    anniversaryStore: anniversaryStore,
                    weeklyTodoStore: weeklyTodoStore,
                    tonightDinnerStore: tonightDinnerStore,
                    ritualStore: ritualStore,
                    currentStatusStore: currentStatusStore,
                    whisperNoteStore: whisperNoteStore
                )
                return
            }

            let didApply = self.applyLatestPulledContent(
                to: scope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore,
                eventTextOverride: "已自动应用最近共享内容"
            )

            if didApply {
                self.deferredAutomaticApplyTask?.cancel()
                self.deferredAutomaticApplyTask = nil
                self.lastDeferredRemoteUpdatedAt = nil
            }
        }
    }

    func buildSnapshot(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        scope: AppContentScope
    ) -> SyncContentPayload {
        let deletedMemoryIDs = Set(memoryTombstones.map(\.id))
        let deletedWishIDs = Set(wishTombstones.map(\.id))
        return SyncContentPayload(
            scope: scope,
            memories: memories.filter { deletedMemoryIDs.contains($0.id) == false },
            memoryTombstones: memoryTombstones,
            wishes: wishes.filter { deletedWishIDs.contains($0.id) == false },
            wishTombstones: wishTombstones,
            anniversaries: anniversaries,
            weeklyTodos: weeklyTodos,
            tonightDinners: tonightDinners,
            rituals: rituals,
            currentStatuses: currentStatuses,
            whisperNotes: whisperNotes,
            relationStatus: relationshipStore.state.relationStatus,
            updatedAt: .now
        )
    }

    private var hasPendingAutomaticPush: Bool {
        defaults.bool(forKey: Self.pendingAutomaticPushDefaultsKey)
    }

    private func markPendingAutomaticPush(_ isPending: Bool) {
        defaults.set(isPending, forKey: Self.pendingAutomaticPushDefaultsKey)
        debugAutomaticPush("pending flag updated value=\(isPending)")
    }

    // Future sync handoff:
    // 真实 sync API 接通后，先得到 RemoteSyncSnapshotPayload，
    // 再从这里映射成当前本地同步体系使用的 SyncContentPayload。
    func mapRemoteSnapshotPayload(_ payload: RemoteSyncSnapshotPayload) -> SyncContentPayload {
        .fromRemoteSnapshotPayload(payload)
    }

    @discardableResult
    func rehearseRemoteSnapshotPayload(
        _ payload: RemoteSyncSnapshotPayload,
        to scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore
    ) -> Bool {
        guard sessionStore.state.sessionSource == .authenticated else {
            latestErrorText = "请先接入一份可用账号结果。"
            latestEventText = "同步返回演练需要先连接账号"
            publishStatus()
            return false
        }

        let mappedPayload = mapRemoteSnapshotPayload(payload)

        guard mappedPayload.scope.spaceId == scope.spaceId else {
            latestErrorText = "这份同步返回结果不属于当前空间。"
            latestEventText = "请切回对应空间后再继续演练"
            publishStatus()
            return false
        }

        latestPulledPayload = mappedPayload
        remoteSummary = SyncRemotePayloadSummary(payload: mappedPayload)
        lastPullAt = .now
        latestErrorText = nil
        latestEventText = "已承接一份同步返回演练结果"
        publishStatus()

        return applyLatestPulledContent(
            to: scope,
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

    func makeRequestContext(scope: AppContentScope) throws -> AppSyncRequestContext {
        guard let accountId = sessionStore.state.account?.accountId else {
            throw AppSyncPrototypeError.remoteUnavailable
        }

        return AppSyncRequestContext(
            accountId: accountId,
            currentUserId: scope.currentUserId,
            partnerUserId: scope.partnerUserId,
            spaceId: scope.spaceId
        )
    }

    private func resolveManualBackendSyncTarget(
        preferredScope: AppContentScope
    ) async throws -> ManualBackendSyncTarget {
        guard sessionStore.state.sessionSource == .authenticated else {
            throw AppSyncPrototypeError.authenticatedSessionRequired
        }

        await relationshipStore.refreshRemoteRelationshipStatusIfNeeded()

        let relationshipState = relationshipStore.state
        guard relationshipState.connectionMode == .backendRemote,
              relationshipState.space != nil else {
            throw AppSyncPrototypeError.backendSpaceRequired
        }

        guard let accountId = sessionStore.state.account?.accountId else {
            throw AppSyncPrototypeError.authenticatedSessionRequired
        }

        let relationshipAccountId = relationshipState.currentAccountId?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let relationshipAccountId,
           relationshipAccountId.isEmpty == false,
           relationshipAccountId != accountId {
            throw AppSyncPrototypeError.relationshipScopeMismatch
        }

        let resolvedScope = relationshipState.contentScope
        let resolvedContext = AppSyncRequestContext(
            accountId: accountId,
            currentUserId: resolvedScope.currentUserId,
            partnerUserId: resolvedScope.partnerUserId,
            spaceId: resolvedScope.spaceId
        )

        if preferredScope.spaceId != resolvedScope.spaceId
            || preferredScope.currentUserId != resolvedScope.currentUserId
            || preferredScope.partnerUserId != resolvedScope.partnerUserId {
            latestEventText = "已改用当前账号 \(accountId) 在空间 \(resolvedScope.spaceId) 的真实身份继续同步"
            publishStatus()
        }

        return ManualBackendSyncTarget(
            scope: resolvedScope,
            context: resolvedContext
        )
    }

    func pushContent(_ payload: SyncContentPayload) async throws {
        let context = try makeRequestContext(scope: payload.scope)
        try await remoteProvider.pushContent(payload, context: context)
    }

    func pullLatestContent(scope: AppContentScope) async throws -> SyncContentPayload {
        let context = try makeRequestContext(scope: scope)
        return try await remoteProvider.pullContent(for: context)
    }

    func refreshRemoteSummary(for scope: AppContentScope) async {
        do {
            let context = try makeRequestContext(scope: scope)
            remoteSummary = try await remoteProvider.fetchRemoteSummary(for: context)
            latestErrorText = nil
            publishStatus()
        } catch {
            remoteSummary = nil
            latestErrorText = error.localizedDescription
            publishStatus()
        }
    }

    @discardableResult
    func pushCurrentScopeContent(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        scope: AppContentScope
    ) async -> Bool {
        isSyncing = true
        latestErrorText = nil
        latestEventText = "正在整理并推送内容"
        publishStatus()

        let payload = buildSnapshot(
            memories: memories,
            memoryTombstones: memoryTombstones,
            wishes: wishes,
            wishTombstones: wishTombstones,
            anniversaries: anniversaries,
            weeklyTodos: weeklyTodos,
            tonightDinners: tonightDinners,
            rituals: rituals,
            currentStatuses: currentStatuses,
            whisperNotes: whisperNotes,
            scope: scope
        )

        do {
            try await pushContent(payload)
            remoteSummary = SyncRemotePayloadSummary(payload: payload)
            lastPushAt = .now
            latestEventText = "已同步到当前云端空间"
            isSyncing = false
            publishStatus()
            return true
        } catch {
            latestErrorText = error.localizedDescription
            latestEventText = "这次没有同步成功"
            isSyncing = false
            publishStatus()
            return false
        }
    }

    @discardableResult
    func pullCurrentScopeContent(scope: AppContentScope) async -> SyncContentPayload? {
        isSyncing = true
        latestErrorText = nil
        latestEventText = "正在拉取最近一份云端内容"
        publishStatus()

        do {
            let payload = try await pullLatestContent(scope: scope)
            latestPulledPayload = payload
            remoteSummary = SyncRemotePayloadSummary(payload: payload)
            lastPullAt = .now
            latestEventText = "已从云端拉取最近内容"
            isSyncing = false
            publishStatus()
            return payload
        } catch {
            latestErrorText = error.localizedDescription
            latestEventText = "暂时还没有拉取到云端内容"
            isSyncing = false
            publishStatus()
            return nil
        }
    }

    @discardableResult
    func pullCurrentScopeContentFromLocalBackend(scope: AppContentScope) async -> SyncContentPayload? {
        await pullCurrentScopeContentFromLocalBackend(
            scope: scope,
            eventTextOverride: nil,
            shouldRecordErrors: true,
            shouldSurfaceActivity: true
        )
    }

    @discardableResult
    private func pullCurrentScopeContentFromLocalBackend(
        scope: AppContentScope,
        eventTextOverride: String?,
        shouldRecordErrors: Bool,
        shouldSurfaceActivity: Bool
    ) async -> SyncContentPayload? {
        isSyncing = true
        if shouldSurfaceActivity {
            if shouldRecordErrors {
                latestErrorText = nil
            }
            if eventTextOverride == nil {
                latestEventText = "正在从测试环境读取最近快照"
            }
            publishStatus()
        }

        do {
            let target = try await resolveManualBackendSyncTarget(preferredScope: scope)
            let context = target.context
            if shouldSurfaceActivity, eventTextOverride == nil {
                latestEventText = "正在以 \(context.accountId) / \(context.currentUserId) 读取 GET /spaces/\(context.spaceId)/snapshot"
                publishStatus()
            }
            let payload = try await realSyncProvider.pullContent(for: context)
            debugWhisperSync("pull complete space=\(payload.scope.spaceId) whisperNotes=\(payload.whisperNotes.count)")
            debugMemorySync(
                "pull success account=\(context.accountId) user=\(context.currentUserId) space=\(payload.scope.spaceId) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) memories=\(memoryDebugSummary(payload.memories)) tombstones=\(memoryTombstoneDebugSummary(payload.memoryTombstones))"
            )
            debugWishSync(
                "pull success account=\(context.accountId) user=\(context.currentUserId) space=\(payload.scope.spaceId) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
            )
            latestPulledPayload = payload
            remoteSummary = SyncRemotePayloadSummary(payload: payload)
            lastPullAt = .now
            isSyncing = false
            if shouldSurfaceActivity {
                latestEventText = eventTextOverride
                    ?? "已以 \(context.accountId) / \(context.currentUserId) 从测试环境拉取最近快照"
                if shouldRecordErrors {
                    latestErrorText = nil
                }
                publishStatus()
            }
            return payload
        } catch {
            isSyncing = false
            if shouldRecordErrors {
                latestErrorText = error.localizedDescription
            }
            if shouldSurfaceActivity {
                latestEventText = "这次没有从测试环境拉取到快照"
                publishStatus()
            }
            return nil
        }
    }

    @discardableResult
    func pushCurrentScopeContentToLocalBackend(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore,
        scope: AppContentScope
    ) async -> Bool {
        let resolvedWeeklyTodos = weeklyTodoStore.items(in: scope)
        let resolvedTonightDinners = tonightDinnerStore.items(in: scope)
        let resolvedRituals = ritualStore.items(in: scope)
        let resolvedCurrentStatuses = currentStatusStore.items(in: scope)
        let resolvedWhisperNotes = whisperNoteStore.items(in: scope)

        return await pushCurrentScopeContentToLocalBackend(
            memories: memories,
            memoryTombstones: memoryTombstones,
            wishes: wishes,
            wishTombstones: wishTombstones,
            anniversaries: anniversaries,
            weeklyTodos: resolvedWeeklyTodos,
            tonightDinners: resolvedTonightDinners,
            rituals: resolvedRituals,
            currentStatuses: resolvedCurrentStatuses,
            whisperNotes: resolvedWhisperNotes,
            scope: scope,
            eventTextOverride: nil,
            shouldRecordErrors: true
        )
    }

    @discardableResult
    private func pushCurrentScopeContentToLocalBackend(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        scope: AppContentScope,
        eventTextOverride: String?,
        shouldRecordErrors: Bool
    ) async -> Bool {
        isSyncing = true
        if shouldRecordErrors {
            latestErrorText = nil
        }
        if eventTextOverride == nil {
            latestEventText = "正在把当前内容同步到测试环境"
        }
        publishStatus()

        do {
            let target = try await resolveManualBackendSyncTarget(preferredScope: scope)
            let context = target.context
            let payload = buildSnapshot(
                memories: memories,
                memoryTombstones: memoryTombstones,
                wishes: wishes,
                wishTombstones: wishTombstones,
                anniversaries: anniversaries,
                weeklyTodos: weeklyTodos,
                tonightDinners: tonightDinners,
                rituals: rituals,
                currentStatuses: currentStatuses,
                whisperNotes: whisperNotes,
                scope: target.scope
            )
            debugWhisperSync("prepare push snapshot space=\(target.scope.spaceId) whisperNotes=\(payload.whisperNotes.count)")
            debugMemorySync(
                "push request account=\(context.accountId) user=\(context.currentUserId) space=\(target.scope.spaceId) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) memories=\(memoryDebugSummary(payload.memories)) tombstones=\(memoryTombstoneDebugSummary(payload.memoryTombstones))"
            )
            debugWishSync(
                "push request account=\(context.accountId) user=\(context.currentUserId) space=\(target.scope.spaceId) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
            )
            if eventTextOverride == nil {
                latestEventText = "正在发送 PUT /spaces/\(context.spaceId)/snapshot（记忆 \(payload.memories.count) 条，记忆删除标记 \(payload.memoryTombstones.count) 条，本周事项 \(weeklyTodos.count) 条，今晚吃什么 \(tonightDinners.count) 条，小约定 \(rituals.count) 条，当前状态 \(currentStatuses.count) 条，悄悄话 \(whisperNotes.count) 条）"
            }
            publishStatus()
            try await realSyncProvider.pushContent(payload, context: context)
            remoteSummary = SyncRemotePayloadSummary(payload: payload)
            lastPushAt = .now
            lastPushedSnapshotUpdatedAt = payload.updatedAt
            debugMemorySync(
                "push success account=\(context.accountId) user=\(context.currentUserId) space=\(target.scope.spaceId) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) memories=\(memoryDebugSummary(payload.memories)) tombstones=\(memoryTombstoneDebugSummary(payload.memoryTombstones))"
            )
            debugWishSync(
                "push success account=\(context.accountId) user=\(context.currentUserId) space=\(target.scope.spaceId) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
            )
            deferredAutomaticApplyTask?.cancel()
            deferredAutomaticApplyTask = nil
            if let latestPulledPayload,
               shouldTreatPulledPayloadAsStaleForAutomaticApply(latestPulledPayload) {
                self.latestPulledPayload = nil
                self.lastDeferredRemoteUpdatedAt = nil
            }
            markPendingAutomaticPush(false)
            latestEventText = eventTextOverride
                ?? "已发送 PUT /spaces/\(context.spaceId)/snapshot（记忆 \(payload.memories.count) 条，记忆删除标记 \(payload.memoryTombstones.count) 条，本周事项 \(weeklyTodos.count) 条，今晚吃什么 \(tonightDinners.count) 条，小约定 \(rituals.count) 条，当前状态 \(currentStatuses.count) 条，悄悄话 \(whisperNotes.count) 条）"
            if shouldRecordErrors {
                latestErrorText = nil
            }
            isSyncing = false
            publishStatus()
            return true
        } catch {
            debugMemorySync("push error space=\(scope.spaceId) error=\(error.localizedDescription)")
            debugWishSync("push error space=\(scope.spaceId) error=\(error.localizedDescription)")
            if shouldRecordErrors {
                latestErrorText = error.localizedDescription
                latestEventText = "这次没有发出 PUT /spaces/\(scope.spaceId)/snapshot"
            }
            isSyncing = false
            publishStatus()
            return false
        }
    }

    @discardableResult
    func applyLatestPulledContent(
        to scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore
    ) -> Bool {
        applyLatestPulledContent(
            to: scope,
            memoryStore: memoryStore,
            wishStore: wishStore,
            anniversaryStore: anniversaryStore,
            weeklyTodoStore: weeklyTodoStore,
            tonightDinnerStore: tonightDinnerStore,
            ritualStore: ritualStore,
            currentStatusStore: currentStatusStore,
            whisperNoteStore: whisperNoteStore,
            eventTextOverride: nil
        )
    }

    @discardableResult
    private func applyLatestPulledContent(
        to scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore,
        eventTextOverride: String?
    ) -> Bool {
        guard let latestPulledPayload else {
            latestErrorText = "还没有可应用到当前空间的云端内容。"
            latestEventText = "请先拉取最近云端内容"
            publishStatus()
            return false
        }

        guard latestPulledPayload.scope.spaceId == scope.spaceId else {
            latestErrorText = "这份云端内容不属于当前共享空间。"
            latestEventText = "请先切回对应空间后再应用"
            publishStatus()
            return false
        }

        let applyScope = latestPulledPayload.scope
        debugWhisperSync("apply latest payload space=\(applyScope.spaceId) whisperNotes=\(latestPulledPayload.whisperNotes.count)")
        isApplyingLatestPulledContent = true
        defer {
            isApplyingLatestPulledContent = false
        }
        let localBeforeEntries = memoryStore.entries(in: applyScope)
        automaticPushSuppressedUntil = Date().addingTimeInterval(2)
        deferredAutomaticApplyTask?.cancel()
        deferredAutomaticApplyTask = nil
        let effectiveMemoryTombstones = memoryStore.mergeDeletionTombstones(
            in: applyScope,
            with: latestPulledPayload.memoryTombstones
        )
        let deletedMemoryIDs = Set(effectiveMemoryTombstones.map(\.id))
        let remoteEffectiveEntries = latestPulledPayload.memories.filter { deletedMemoryIDs.contains($0.id) == false }
        debugMemorySync(
            "apply begin space=\(applyScope.spaceId) payloadUpdatedAt=\(latestPulledPayload.updatedAt.timeIntervalSince1970) localBefore=\(memoryDebugSummary(localBeforeEntries)) remote=\(memoryDebugSummary(remoteEffectiveEntries)) tombstones=\(memoryTombstoneDebugSummary(effectiveMemoryTombstones))"
        )
        let localBeforeWishes = wishStore.wishes(in: applyScope)
        memoryStore.mergeRemoteEntries(
            in: applyScope,
            with: remoteEffectiveEntries
        )
        let effectiveWishTombstones = wishStore.mergeDeletionTombstones(
            in: applyScope,
            with: latestPulledPayload.wishTombstones
        )
        let deletedWishIDs = Set(effectiveWishTombstones.map(\.id))
        let remoteEffectiveWishes = latestPulledPayload.wishes.filter { deletedWishIDs.contains($0.id) == false }
        debugWishSync(
            "apply begin space=\(applyScope.spaceId) payloadUpdatedAt=\(latestPulledPayload.updatedAt.timeIntervalSince1970) localBefore=\(wishDebugSummary(localBeforeWishes)) remote=\(wishDebugSummary(remoteEffectiveWishes)) tombstones=\(wishTombstoneDebugSummary(effectiveWishTombstones))"
        )
        wishStore.mergeRemoteWishes(in: applyScope, with: remoteEffectiveWishes)
        anniversaryStore.replaceAnniversaries(in: applyScope, with: latestPulledPayload.anniversaries)
        weeklyTodoStore.replaceItems(in: applyScope, with: latestPulledPayload.weeklyTodos)
        tonightDinnerStore.replaceItems(in: applyScope, with: latestPulledPayload.tonightDinners)
        ritualStore.replaceItems(in: applyScope, with: latestPulledPayload.rituals)
        currentStatusStore.replaceStatuses(in: applyScope, with: latestPulledPayload.currentStatuses)
        whisperNoteStore.replaceItems(in: applyScope, with: latestPulledPayload.whisperNotes)
        debugWhisperSync("apply finished space=\(applyScope.spaceId) storeWhisperNotes=\(whisperNoteStore.items(in: applyScope).count)")
        let localAfterEntries = memoryStore.entries(in: applyScope)
        let localAfterIDs = Set(localAfterEntries.map(\.id))
        let removedEntries = localBeforeEntries.filter { localAfterIDs.contains($0.id) == false }
        if removedEntries.isEmpty == false {
            debugMemorySync(
                "apply removed local entries space=\(applyScope.spaceId) removed=\(memoryDebugSummary(removedEntries))"
            )
        }
        debugMemorySync(
            "apply end space=\(applyScope.spaceId) final=\(memoryDebugSummary(localAfterEntries))"
        )
        let localAfterWishes = wishStore.wishes(in: applyScope)
        debugWishSync(
            "apply end space=\(applyScope.spaceId) final=\(wishDebugSummary(localAfterWishes))"
        )

        lastAppliedAt = .now
        lastAppliedRemoteUpdatedAt = latestPulledPayload.updatedAt
        if let lastDeferredRemoteUpdatedAt,
           latestPulledPayload.updatedAt >= lastDeferredRemoteUpdatedAt {
            self.lastDeferredRemoteUpdatedAt = nil
        }
        latestErrorText = nil
        latestEventText = eventTextOverride
            ?? "已将最近云端内容应用到当前空间（记忆 \(latestPulledPayload.memories.count) 条，记忆删除标记 \(effectiveMemoryTombstones.count) 条，本周事项 \(latestPulledPayload.weeklyTodos.count) 条，今晚吃什么 \(latestPulledPayload.tonightDinners.count) 条，小约定 \(latestPulledPayload.rituals.count) 条，当前状态 \(latestPulledPayload.currentStatuses.count) 条，悄悄话 \(latestPulledPayload.whisperNotes.count) 条）"
        publishStatus()
        return true
    }

    @discardableResult
    func pullAndApplyCurrentScopeContentFromLocalBackend(
        scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore
    ) async -> Bool {
        isSyncing = true
        latestErrorText = nil
        latestEventText = "正在从测试环境读取并应用最近快照"
        publishStatus()

        do {
            let target = try await resolveManualBackendSyncTarget(preferredScope: scope)
            let context = target.context
            latestEventText = "正在以 \(context.accountId) / \(context.currentUserId) 读取并应用空间 \(context.spaceId) 的快照"
            publishStatus()

            let payload = try await realSyncProvider.pullContent(for: context)
            latestPulledPayload = payload
            remoteSummary = SyncRemotePayloadSummary(payload: payload)
            lastPullAt = .now

            let didApply = applyLatestPulledContent(
                to: target.scope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore
            )

            if didApply {
                latestErrorText = nil
                latestEventText = "已以 \(context.accountId) / \(context.currentUserId) 读取并应用空间 \(context.spaceId) 的快照（记忆 \(payload.memories.count) 条，记忆删除标记 \(payload.memoryTombstones.count) 条，本周事项 \(payload.weeklyTodos.count) 条，今晚吃什么 \(payload.tonightDinners.count) 条，小约定 \(payload.rituals.count) 条，当前状态 \(payload.currentStatuses.count) 条，悄悄话 \(payload.whisperNotes.count) 条）"
            }

            isSyncing = false
            publishStatus()
            return didApply
        } catch {
            latestErrorText = error.localizedDescription
            latestEventText = "这次没有从测试环境拉取到快照"
            isSyncing = false
            publishStatus()
            return false
        }
    }

    private func publishStatus(
        session: AccountSessionState? = nil,
        relationship: CoupleRelationshipState? = nil
    ) {
        status = Self.makeStatus(
            session: session ?? sessionStore.state,
            relationship: relationship ?? relationshipStore.state,
            remoteProvider: remoteProvider,
            remoteSummary: remoteSummary,
            isSyncing: isSyncing,
            latestPulledPayload: latestPulledPayload,
            lastPushAt: lastPushAt,
            lastPullAt: lastPullAt,
            lastAppliedAt: lastAppliedAt,
            lastAppliedRemoteUpdatedAt: lastAppliedRemoteUpdatedAt,
            latestEventText: latestEventText,
            latestErrorText: latestErrorText
        )
    }

    private static func makeStatus(
        session: AccountSessionState,
        relationship: CoupleRelationshipState,
        remoteProvider: AppSyncRemoteProviding,
        remoteSummary: SyncRemotePayloadSummary?,
        isSyncing: Bool,
        latestPulledPayload: SyncContentPayload?,
        lastPushAt: Date?,
        lastPullAt: Date?,
        lastAppliedAt: Date?,
        lastAppliedRemoteUpdatedAt: Date?,
        latestEventText: String?,
        latestErrorText: String?
    ) -> SyncStatusSnapshot {
        let mode: AccountSessionMode
        if session.isCloudSyncEnabled, session.isLoggedIn {
            mode = remoteProvider.availability == .connected ? .cloudConnected : .cloudPrepared
        } else {
            mode = .localOnly
        }

        let summary: String
        let detail: String

        switch mode {
        case .localOnly:
            summary = "当前仍然使用本地真实数据"
            detail = "内容仍然优先保存在本机。等账号能力开启后，这里会继续承接云端连接、同步状态和换机恢复。"
        case .cloudPrepared:
            summary = relationship.isBound ? "云端准备已经就绪" : "换机恢复准备已经就绪"
            detail = "当前已经可以承接账号与云端状态；如需联调测试，可在页面下方连接测试环境。"
        case .cloudConnected:
            summary = "云端同步已接入"
            detail = "这里会继续统一展示账号状态、同步进度和云端空间连接结果。"
        }

        let hasPendingPulledContent: Bool
        let pendingPulledContentText: String?
        if let latestPulledPayload,
           latestPulledPayload.scope == relationship.contentScope,
           lastAppliedRemoteUpdatedAt.map({ latestPulledPayload.updatedAt > $0 }) ?? true {
            hasPendingPulledContent = true
            pendingPulledContentText = "发现新的共享内容，可手动应用"
        } else {
            hasPendingPulledContent = false
            pendingPulledContentText = nil
        }

        return SyncStatusSnapshot(
            mode: mode,
            isUsingLocalData: true,
            accountDisplayName: session.account?.nickname ?? session.sessionSource.label,
            providerLabel: "\(remoteProvider.providerKind.label) · \(remoteProvider.providerName)",
            availabilityLabel: remoteProvider.availability.label,
            hasRemoteContent: remoteSummary != nil,
            remoteSummary: remoteSummary,
            isSyncing: isSyncing,
            canApplyPulledContent: latestPulledPayload?.scope == relationship.contentScope,
            hasPendingPulledContent: hasPendingPulledContent,
            pendingPulledContentText: pendingPulledContentText,
            lastPushAt: lastPushAt,
            lastPullAt: lastPullAt,
            lastAppliedAt: lastAppliedAt,
            latestEventText: latestEventText,
            latestErrorText: latestErrorText,
            summary: summary,
            detail: detail
        )
    }

    private func canAttemptAutomaticBackendSync(for preferredScope: AppContentScope) -> Bool {
        guard sessionStore.state.sessionSource == .authenticated else {
            return false
        }

        let relationshipState = relationshipStore.state
        guard relationshipState.connectionMode == .backendRemote,
              relationshipState.contentScope.isSharedSpace,
              relationshipState.space != nil else {
            return false
        }

        guard let account = sessionStore.state.account else {
            return false
        }

        let accountId = account.accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard accountId.isEmpty == false else {
            return false
        }

        let relationshipAccountId = relationshipState.currentAccountId?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let relationshipAccountId,
           relationshipAccountId.isEmpty == false,
           relationshipAccountId != accountId {
            return false
        }

        let resolvedScope = relationshipState.contentScope
        return preferredScope == resolvedScope
    }

    var automaticPullHeartbeatSeconds: TimeInterval {
        automaticPullHeartbeatInterval
    }

    func schedulePostPushConvergencePullIfPossible(
        scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore
    ) {
        guard canAttemptAutomaticBackendSync(for: scope) else { return }

        if postPushConvergencePullTask != nil {
            debugMemorySync("convergence pull cancel previous pending scope=\(scope.spaceId)")
        }
        postPushConvergencePullTask?.cancel()
        debugAutomaticPush(
            "schedule post-push convergence pull delay=\(String(format: "%.2f", postPushConvergencePullDelay))s"
        )
        debugMemorySync(
            "convergence pull scheduled scope=\(scope.spaceId) delay=\(String(format: "%.2f", postPushConvergencePullDelay))s lastPushedSnapshotUpdatedAt=\(lastPushedSnapshotUpdatedAt?.timeIntervalSince1970.description ?? "nil")"
        )
        postPushConvergencePullTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let nanoseconds = UInt64((self.postPushConvergencePullDelay * 1_000_000_000).rounded(.up))
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                debugAutomaticPush("post-push convergence pull cancelled before start")
                debugMemorySync("convergence pull cancelled before start scope=\(scope.spaceId)")
                return
            }

            guard !Task.isCancelled else { return }
            guard self.canAttemptAutomaticBackendSync(for: scope) else {
                debugAutomaticPush("post-push convergence pull skipped reason=backend sync unavailable")
                debugMemorySync("convergence pull skipped scope=\(scope.spaceId) reason=backend sync unavailable")
                return
            }
            guard self.isSyncing == false else {
                debugAutomaticPush("post-push convergence pull skipped reason=sync still running")
                debugMemorySync("convergence pull skipped scope=\(scope.spaceId) reason=sync still running")
                return
            }

            self.lastAutomaticPullAt = nil
            debugAutomaticPush("perform post-push convergence pull")
            debugMemorySync("convergence pull execute scope=\(scope.spaceId)")
            self.scheduleAutomaticPullIfPossible(
                scope: scope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore,
                trigger: .foregroundHeartbeat
            )
        }
    }

    private func automaticApplyDelayIfPossible(
        for payload: SyncContentPayload,
        into scope: AppContentScope
    ) -> TimeInterval? {
        guard canAttemptAutomaticBackendSync(for: scope) else {
            return nil
        }

        guard payload.scope == relationshipStore.state.contentScope else {
            return nil
        }

        if let lastAppliedRemoteUpdatedAt,
           payload.updatedAt <= lastAppliedRemoteUpdatedAt {
            return nil
        }

        if let staleReason = hardStaleReasonForAutomaticApply(payload) {
            debugAutomaticPush(
                "automatic apply rejected stale payload reason=\(staleReason)"
            )
            debugMemorySync(
                "automatic apply rejected stale payload reason=\(staleReason) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) memories=\(memoryDebugSummary(payload.memories)) tombstones=\(memoryTombstoneDebugSummary(payload.memoryTombstones))"
            )
            debugWishSync(
                "automatic apply rejected stale payload reason=\(staleReason) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
            )
            return nil
        }

        let now = Date()
        var requiredDelay: TimeInterval = 0
        var delayReasons: [String] = []
        if hasPendingAutomaticPush {
            requiredDelay = max(requiredDelay, 1)
            delayReasons.append("pending automatic push")
        }
        if let lastLocalSharedContentMutationAt,
           now.timeIntervalSince(lastLocalSharedContentMutationAt) < automaticApplyLocalMutationCooldown {
            let remaining = automaticApplyLocalMutationCooldown - now.timeIntervalSince(lastLocalSharedContentMutationAt)
            requiredDelay = max(
                requiredDelay,
                remaining
            )
            delayReasons.append("recent local mutation cooldown=\(String(format: "%.2f", remaining))s")
        }

        if let lastPushAt,
           now.timeIntervalSince(lastPushAt) < automaticApplyRecentPushCooldown {
            let remaining = automaticApplyRecentPushCooldown - now.timeIntervalSince(lastPushAt)
            requiredDelay = max(
                requiredDelay,
                remaining
            )
            delayReasons.append("recent push cooldown=\(String(format: "%.2f", remaining))s")
        }

        if let suppressedUntil = automaticPushSuppressedUntil,
           suppressedUntil > now {
            let remaining = suppressedUntil.timeIntervalSince(now)
            requiredDelay = max(requiredDelay, remaining)
            delayReasons.append("automatic push suppressed=\(String(format: "%.2f", remaining))s")
        }

        if delayReasons.isEmpty == false {
            debugMemorySync(
                "automatic apply delayed payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) reasons=\(delayReasons.joined(separator: "; "))"
            )
            debugWishSync(
                "automatic apply delayed payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) reasons=\(delayReasons.joined(separator: "; ")) wishes=\(wishDebugSummary(payload.wishes))"
            )
        }

        return max(0, requiredDelay)
    }

    private func scheduleDeferredAutomaticApplyIfPossible(
        after delay: TimeInterval,
        payload: SyncContentPayload,
        scope: AppContentScope,
        memoryStore: MemoryStore,
        wishStore: WishStore,
        anniversaryStore: AnniversaryStore,
        weeklyTodoStore: WeeklyTodoStore,
        tonightDinnerStore: TonightDinnerStore,
        ritualStore: RitualStore,
        currentStatusStore: CurrentStatusStore,
        whisperNoteStore: WhisperNoteStore
    ) {
        guard delay > 0 else { return }
        if deferredAutomaticApplyTask != nil {
            debugMemorySync("deferred apply cancel previous payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)")
        }
        deferredAutomaticApplyTask?.cancel()
        debugMemorySync(
            "deferred apply scheduled scope=\(scope.spaceId) delay=\(String(format: "%.2f", delay))s payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) memories=\(memoryDebugSummary(payload.memories)) tombstones=\(memoryTombstoneDebugSummary(payload.memoryTombstones))"
        )
        debugWishSync(
            "deferred apply scheduled scope=\(scope.spaceId) delay=\(String(format: "%.2f", delay))s payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
        )
        deferredAutomaticApplyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let nanoseconds = UInt64((delay * 1_000_000_000).rounded(.up))
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                debugMemorySync("deferred apply cancelled before execution payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)")
                return
            }

            guard !Task.isCancelled else { return }
            guard self.latestPulledPayload?.updatedAt == payload.updatedAt else { return }
            debugMemorySync("deferred apply wake payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)")
            if let staleReason = self.hardStaleReasonForAutomaticApply(payload) {
                debugAutomaticPush(
                    "deferred automatic apply dropped stale payload reason=\(staleReason)"
                )
                debugMemorySync(
                    "deferred apply dropped stale payload reason=\(staleReason) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)"
                )
                debugWishSync(
                    "deferred apply dropped stale payload reason=\(staleReason) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)"
                )
                if self.latestPulledPayload?.updatedAt == payload.updatedAt {
                    self.latestPulledPayload = nil
                }
                self.lastDeferredRemoteUpdatedAt = nil
                return
            }
            guard let recheckDelay = self.automaticApplyDelayIfPossible(for: payload, into: scope) else { return }
            if recheckDelay > 0 {
                debugMemorySync(
                    "deferred apply rescheduled payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) delay=\(String(format: "%.2f", recheckDelay))s"
                )
                debugWishSync(
                    "deferred apply rescheduled payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) delay=\(String(format: "%.2f", recheckDelay))s"
                )
                self.scheduleDeferredAutomaticApplyIfPossible(
                    after: recheckDelay,
                    payload: payload,
                    scope: scope,
                    memoryStore: memoryStore,
                    wishStore: wishStore,
                    anniversaryStore: anniversaryStore,
                    weeklyTodoStore: weeklyTodoStore,
                    tonightDinnerStore: tonightDinnerStore,
                    ritualStore: ritualStore,
                    currentStatusStore: currentStatusStore,
                    whisperNoteStore: whisperNoteStore
                )
                return
            }

            debugMemorySync("deferred apply execute payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)")
            debugWishSync("deferred apply execute payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970)")
            let didApply = self.applyLatestPulledContent(
                to: scope,
                memoryStore: memoryStore,
                wishStore: wishStore,
                anniversaryStore: anniversaryStore,
                weeklyTodoStore: weeklyTodoStore,
                tonightDinnerStore: tonightDinnerStore,
                ritualStore: ritualStore,
                currentStatusStore: currentStatusStore,
                whisperNoteStore: whisperNoteStore,
                eventTextOverride: "已在安全时机自动应用最近共享内容"
            )
            if didApply {
                debugMemorySync("deferred apply finished payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) result=success")
                debugWishSync("deferred apply finished payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) result=success")
                self.lastDeferredRemoteUpdatedAt = nil
            }
        }
    }

    private func shouldTreatPulledPayloadAsStaleForAutomaticApply(
        _ payload: SyncContentPayload
    ) -> Bool {
        hardStaleReasonForAutomaticApply(payload) != nil
    }

    private func hardStaleReasonForAutomaticApply(_ payload: SyncContentPayload) -> String? {
        var reasons: [String] = []

        if let lastPushedSnapshotUpdatedAt,
           payload.updatedAt < lastPushedSnapshotUpdatedAt {
            reasons.append(
                "payload older than last successful snapshot (\(payload.updatedAt.timeIntervalSince1970) < \(lastPushedSnapshotUpdatedAt.timeIntervalSince1970))"
            )
        }

        return reasons.isEmpty ? nil : reasons.joined(separator: "; ")
    }

    private func memoryDebugSummary(_ entries: [MemoryTimelineEntry]) -> String {
        if entries.isEmpty {
            return "[]"
        }

        let ids = entries
            .sorted { $0.updatedAt < $1.updatedAt }
            .map {
                "\($0.id.uuidString.lowercased())|user=\($0.createdByUserId)|updatedAt=\($0.updatedAt.timeIntervalSince1970)"
            }
            .joined(separator: ",")
        return "[\(ids)]"
    }

    private func memoryTombstoneDebugSummary(_ tombstones: [MemoryDeletionTombstone]) -> String {
        if tombstones.isEmpty {
            return "[]"
        }

        let ids = tombstones
            .sorted { $0.deletedAt < $1.deletedAt }
            .map {
                "\($0.id.uuidString.lowercased())|deletedBy=\($0.deletedByUserId)|deletedAt=\($0.deletedAt.timeIntervalSince1970)"
            }
            .joined(separator: ",")
        return "[\(ids)]"
    }

    private func wishDebugSummary(_ wishes: [PlaceWish]) -> String {
        if wishes.isEmpty {
            return "[]"
        }

        let ids = wishes
            .sorted { $0.updatedAt < $1.updatedAt }
            .map {
                "\($0.id.uuidString.lowercased())|user=\($0.createdByUserId)|updatedAt=\($0.updatedAt.timeIntervalSince1970)|category=\($0.category.rawValue)|status=\($0.status.rawValue)"
            }
            .joined(separator: ",")
        return "[\(ids)]"
    }

    private func wishTombstoneDebugSummary(_ tombstones: [WishDeletionTombstone]) -> String {
        if tombstones.isEmpty {
            return "[]"
        }

        let ids = tombstones
            .sorted { $0.deletedAt < $1.deletedAt }
            .map {
                "\($0.id.uuidString.lowercased())|deletedBy=\($0.deletedByUserId)|deletedAt=\($0.deletedAt.timeIntervalSince1970)"
            }
            .joined(separator: ",")
        return "[\(ids)]"
    }

    private func notePendingPulledContentIfNeeded(
        _ payload: SyncContentPayload,
        trigger: AutomaticSyncTrigger
    ) {
        guard payload.scope == relationshipStore.state.contentScope else { return }
        guard lastAppliedRemoteUpdatedAt.map({ payload.updatedAt > $0 }) ?? true else { return }
        guard lastDeferredRemoteUpdatedAt.map({ payload.updatedAt > $0 }) ?? true else { return }

        lastDeferredRemoteUpdatedAt = payload.updatedAt
        latestErrorText = nil
        debugWishSync(
            "pending pulled payload trigger=\(trigger.rawValue) payloadUpdatedAt=\(payload.updatedAt.timeIntervalSince1970) wishes=\(wishDebugSummary(payload.wishes)) tombstones=\(wishTombstoneDebugSummary(payload.wishTombstones))"
        )
        switch trigger {
        case .appBecameActive:
            latestEventText = "回到前台后发现新的共享内容，可手动应用"
        case .meViewAppeared:
            latestEventText = "进入“我的”页时发现新的共享内容，可手动应用"
        case .accountSyncAppeared:
            latestEventText = "进入“账号与同步”页时发现新的共享内容，可手动应用"
        case .foregroundHeartbeat:
            latestEventText = "发现新的共享内容，正在等待安全时机自动应用"
        case .memoriesChanged, .wishesChanged, .anniversariesChanged, .weeklyTodosChanged, .tonightDinnersChanged, .ritualsChanged, .currentStatusesChanged, .whisperNotesChanged:
            latestEventText = "发现新的共享内容，可手动应用"
        }
        publishStatus()
    }
}
private extension AppSyncService {
    func automaticPushSignature(
        memories: [MemoryTimelineEntry],
        memoryTombstones: [MemoryDeletionTombstone],
        wishes: [PlaceWish],
        wishTombstones: [WishDeletionTombstone],
        anniversaries: [AnniversaryItem],
        weeklyTodos: [WeeklyTodoItem],
        tonightDinners: [TonightDinnerOption],
        rituals: [RitualItem],
        currentStatuses: [CurrentStatusItem],
        whisperNotes: [WhisperNoteItem],
        scope: AppContentScope
    ) -> String {
        let memorySignature = memories
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.updatedAt.timeIntervalSince1970)|\($0.photoFilename ?? "")" }
            .joined(separator: ",")
        let memoryTombstoneSignature = memoryTombstones
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.deletedAt.timeIntervalSince1970)|\($0.deletedByUserId)" }
            .joined(separator: ",")
        let wishSignature = wishes
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                [
                    $0.id.uuidString,
                    String($0.updatedAt.timeIntervalSince1970),
                    String($0.titleUpdatedAt.timeIntervalSince1970),
                    String($0.detailUpdatedAt.timeIntervalSince1970),
                    String($0.noteUpdatedAt.timeIntervalSince1970),
                    String($0.categoryUpdatedAt.timeIntervalSince1970),
                    String($0.statusUpdatedAt.timeIntervalSince1970),
                    String($0.targetTextUpdatedAt.timeIntervalSince1970)
                ].joined(separator: "|")
            }
            .joined(separator: ",")
        let wishTombstoneSignature = wishTombstones
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.deletedAt.timeIntervalSince1970)|\($0.deletedByUserId)" }
            .joined(separator: ",")
        let anniversarySignature = anniversaries
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: ",")
        let weeklyTodoSignature = weeklyTodos
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.updatedAt.timeIntervalSince1970)|\($0.isCompleted)" }
            .joined(separator: ",")
        let tonightDinnerSignature = tonightDinners
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.status.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.decidedAt?.timeIntervalSince1970 ?? 0)" }
            .joined(separator: ",")
        let ritualSignature = rituals
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.kind.rawValue)|\($0.isCompleted)|\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: ",")
        let currentStatusSignature = currentStatuses
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.updatedAt.timeIntervalSince1970)|\($0.displayText)" }
            .joined(separator: ",")
        let whisperSignature = whisperNotes
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.createdAt.timeIntervalSince1970)|\($0.content)" }
            .joined(separator: ",")

        return [
            scope.spaceId,
            scope.currentUserId,
            scope.partnerUserId ?? "",
            scope.isSharedSpace ? "shared" : "local",
            memorySignature,
            memoryTombstoneSignature,
            wishSignature,
            wishTombstoneSignature,
            anniversarySignature,
            weeklyTodoSignature,
            tonightDinnerSignature,
            ritualSignature,
            currentStatusSignature,
            whisperSignature
        ].joined(separator: "#")
    }
}

private struct StoredRemotePayload: Codable {
    let scope: StoredAppContentScope
    let memories: [StoredRemoteMemory]
    let memoryTombstones: [StoredRemoteMemoryTombstone]
    let wishes: [StoredRemoteWish]
    let wishTombstones: [StoredRemoteWishTombstone]
    let anniversaries: [StoredRemoteAnniversary]
    let weeklyTodos: [StoredRemoteWeeklyTodo]
    let tonightDinners: [StoredRemoteTonightDinner]
    let rituals: [StoredRemoteRitual]
    let currentStatuses: [StoredRemoteCurrentStatus]
    let whisperNotes: [StoredRemoteWhisperNote]
    let relationStatusRawValue: String
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case scope
        case memories
        case memoryTombstones
        case wishes
        case wishTombstones
        case anniversaries
        case weeklyTodos
        case tonightDinners
        case rituals
        case currentStatuses
        case whisperNotes
        case relationStatusRawValue
        case updatedAt
    }

    init(payload: SyncContentPayload) {
        scope = StoredAppContentScope(scope: payload.scope)
        memories = payload.memories.map(StoredRemoteMemory.init)
        memoryTombstones = payload.memoryTombstones.map(StoredRemoteMemoryTombstone.init)
        wishes = payload.wishes.map(StoredRemoteWish.init)
        wishTombstones = payload.wishTombstones.map(StoredRemoteWishTombstone.init)
        anniversaries = payload.anniversaries.map(StoredRemoteAnniversary.init)
        weeklyTodos = payload.weeklyTodos.map(StoredRemoteWeeklyTodo.init)
        tonightDinners = payload.tonightDinners.map(StoredRemoteTonightDinner.init)
        rituals = payload.rituals.map(StoredRemoteRitual.init)
        currentStatuses = payload.currentStatuses.map(StoredRemoteCurrentStatus.init)
        whisperNotes = payload.whisperNotes.map(StoredRemoteWhisperNote.init)
        relationStatusRawValue = payload.relationStatus.rawValue
        updatedAt = payload.updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scope = try container.decode(StoredAppContentScope.self, forKey: .scope)
        memories = try container.decodeIfPresent([StoredRemoteMemory].self, forKey: .memories) ?? []
        memoryTombstones = try container.decodeIfPresent([StoredRemoteMemoryTombstone].self, forKey: .memoryTombstones) ?? []
        wishes = try container.decodeIfPresent([StoredRemoteWish].self, forKey: .wishes) ?? []
        wishTombstones = try container.decodeIfPresent([StoredRemoteWishTombstone].self, forKey: .wishTombstones) ?? []
        anniversaries = try container.decodeIfPresent([StoredRemoteAnniversary].self, forKey: .anniversaries) ?? []
        weeklyTodos = try container.decodeIfPresent([StoredRemoteWeeklyTodo].self, forKey: .weeklyTodos) ?? []
        tonightDinners = try container.decodeIfPresent([StoredRemoteTonightDinner].self, forKey: .tonightDinners) ?? []
        rituals = try container.decodeIfPresent([StoredRemoteRitual].self, forKey: .rituals) ?? []
        currentStatuses = try container.decodeIfPresent([StoredRemoteCurrentStatus].self, forKey: .currentStatuses) ?? []
        whisperNotes = try container.decodeIfPresent([StoredRemoteWhisperNote].self, forKey: .whisperNotes) ?? []
        relationStatusRawValue = try container.decode(String.self, forKey: .relationStatusRawValue)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var summary: SyncRemotePayloadSummary {
        SyncRemotePayloadSummary(
            spaceId: scope.spaceId,
            relationStatus: CoupleRelationStatus(rawValue: relationStatusRawValue) ?? .unpaired,
            memoryCount: memories.count,
            wishCount: wishes.count,
            anniversaryCount: anniversaries.count,
            weeklyTodoCount: weeklyTodos.count,
            tonightDinnerCount: tonightDinners.count,
            ritualCount: rituals.count,
            currentStatusCount: currentStatuses.count,
            whisperNoteCount: whisperNotes.count,
            updatedAt: updatedAt
        )
    }

    var model: SyncContentPayload {
        SyncContentPayload(
            scope: scope.model,
            memories: memories.map(\.model),
            memoryTombstones: memoryTombstones.map(\.model),
            wishes: wishes.map(\.model),
            wishTombstones: wishTombstones.map(\.model),
            anniversaries: anniversaries.map(\.model),
            weeklyTodos: weeklyTodos.map(\.model),
            tonightDinners: tonightDinners.map(\.model),
            rituals: rituals.map(\.model),
            currentStatuses: currentStatuses.map(\.model),
            whisperNotes: whisperNotes.map(\.model),
            relationStatus: CoupleRelationStatus(rawValue: relationStatusRawValue) ?? .unpaired,
            updatedAt: updatedAt
        )
    }
}

private struct StoredAppContentScope: Codable {
    let currentUserId: String
    let partnerUserId: String?
    let spaceId: String
    let isSharedSpace: Bool

    init(scope: AppContentScope) {
        currentUserId = scope.currentUserId
        partnerUserId = scope.partnerUserId
        spaceId = scope.spaceId
        isSharedSpace = scope.isSharedSpace
    }

    var model: AppContentScope {
        AppContentScope(
            currentUserId: currentUserId,
            partnerUserId: partnerUserId,
            spaceId: spaceId,
            isSharedSpace: isSharedSpace
        )
    }
}

private struct StoredRemoteMemory: Codable {
    let id: UUID
    let title: String
    let detail: String
    let date: Date
    let categoryRawValue: String
    let imageLabel: String
    let mood: String
    let location: String
    let weather: String
    let isFeatured: Bool
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(_ entry: MemoryTimelineEntry) {
        id = entry.id
        title = entry.title
        detail = entry.detail
        date = entry.date
        categoryRawValue = entry.category.rawValue
        imageLabel = entry.imageLabel
        mood = entry.mood
        location = entry.location
        weather = entry.weather
        isFeatured = entry.isFeatured
        spaceId = entry.spaceId
        createdByUserId = entry.createdByUserId
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        syncStatusRawValue = entry.syncStatus.rawValue
    }

    var model: MemoryTimelineEntry {
        MemoryTimelineEntry(
            id: id,
            title: title,
            detail: detail,
            date: date,
            category: MemoryCategory(rawValue: categoryRawValue) ?? .daily,
            imageLabel: imageLabel,
            mood: mood,
            location: location,
            weather: weather,
            isFeatured: isFeatured,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

private struct StoredRemoteMemoryTombstone: Codable {
    let id: UUID
    let spaceId: String
    let deletedByUserId: String
    let deletedAt: Date

    init(_ tombstone: MemoryDeletionTombstone) {
        id = tombstone.id
        spaceId = tombstone.spaceId
        deletedByUserId = tombstone.deletedByUserId
        deletedAt = tombstone.deletedAt
    }

    var model: MemoryDeletionTombstone {
        MemoryDeletionTombstone(
            id: id,
            spaceId: spaceId,
            deletedByUserId: deletedByUserId,
            deletedAt: deletedAt
        )
    }
}

private struct StoredRemoteWish: Codable {
    let id: UUID
    let title: String
    let titleUpdatedAt: Date?
    let detail: String
    let detailUpdatedAt: Date?
    let note: String
    let noteUpdatedAt: Date?
    let categoryRawValue: String
    let categoryUpdatedAt: Date?
    let statusRawValue: String
    let statusUpdatedAt: Date?
    let targetText: String
    let targetTextUpdatedAt: Date?
    let symbol: String
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let updatedAtTimestamp: TimeInterval?
    let syncStatusRawValue: String

    init(_ wish: PlaceWish) {
        id = wish.id
        title = wish.title
        titleUpdatedAt = wish.titleUpdatedAt
        detail = wish.detail
        detailUpdatedAt = wish.detailUpdatedAt
        note = wish.note
        noteUpdatedAt = wish.noteUpdatedAt
        categoryRawValue = wish.category.rawValue
        categoryUpdatedAt = wish.categoryUpdatedAt
        statusRawValue = wish.status.rawValue
        statusUpdatedAt = wish.statusUpdatedAt
        targetText = wish.targetText
        targetTextUpdatedAt = wish.targetTextUpdatedAt
        symbol = wish.symbol
        spaceId = wish.spaceId
        createdByUserId = wish.createdByUserId
        createdAt = wish.createdAt
        updatedAt = wish.updatedAt
        updatedAtTimestamp = wish.updatedAt.timeIntervalSince1970
        syncStatusRawValue = wish.syncStatus.rawValue
    }

    var model: PlaceWish {
        let resolvedUpdatedAt = updatedAtTimestamp.map(Date.init(timeIntervalSince1970:)) ?? updatedAt
        return PlaceWish(
            id: id,
            title: title,
            titleUpdatedAt: titleUpdatedAt,
            detail: detail,
            detailUpdatedAt: detailUpdatedAt,
            note: note,
            noteUpdatedAt: noteUpdatedAt,
            category: WishCategory(rawValue: categoryRawValue) ?? .date,
            categoryUpdatedAt: categoryUpdatedAt,
            status: WishStatus(rawValue: statusRawValue) ?? .dreaming,
            statusUpdatedAt: statusUpdatedAt,
            targetText: targetText,
            targetTextUpdatedAt: targetTextUpdatedAt,
            symbol: symbol,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: resolvedUpdatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

private struct StoredRemoteWishTombstone: Codable {
    let id: UUID
    let spaceId: String
    let deletedByUserId: String
    let deletedAt: Date

    init(_ tombstone: WishDeletionTombstone) {
        id = tombstone.id
        spaceId = tombstone.spaceId
        deletedByUserId = tombstone.deletedByUserId
        deletedAt = tombstone.deletedAt
    }

    var model: WishDeletionTombstone {
        WishDeletionTombstone(
            id: id,
            spaceId: spaceId,
            deletedByUserId: deletedByUserId,
            deletedAt: deletedAt
        )
    }
}

private struct StoredRemoteAnniversary: Codable {
    let id: UUID
    let title: String
    let date: Date
    let categoryRawValue: String
    let note: String
    let cadenceRawValue: String
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(_ item: AnniversaryItem) {
        id = item.id
        title = item.title
        date = item.date
        categoryRawValue = item.category.rawValue
        note = item.note
        cadenceRawValue = item.cadence.rawValue
        spaceId = item.spaceId
        createdByUserId = item.createdByUserId
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: AnniversaryItem {
        AnniversaryItem(
            id: id,
            title: title,
            date: date,
            category: AnniversaryCategory(rawValue: categoryRawValue) ?? .custom,
            note: note,
            cadence: AnniversaryCadence(rawValue: cadenceRawValue) ?? .yearly,
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

private struct StoredRemoteWeeklyTodo: Codable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let scheduledDate: Date?
    let ownerRawValue: String?
    let spaceId: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let syncStatusRawValue: String

    init(_ item: WeeklyTodoItem) {
        id = item.id
        title = item.title
        isCompleted = item.isCompleted
        scheduledDate = item.scheduledDate
        ownerRawValue = item.owner?.rawValue
        spaceId = item.spaceId
        createdByUserId = item.createdByUserId
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: WeeklyTodoItem {
        WeeklyTodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            scheduledDate: scheduledDate,
            owner: ownerRawValue.flatMap(WeeklyTodoOwner.init(rawValue:)),
            spaceId: spaceId,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

private struct StoredRemoteTonightDinner: Codable {
    let id: UUID
    let title: String
    let note: String
    let statusRawValue: String
    let createdAt: Date
    let decidedAt: Date?
    let createdByUserId: String
    let spaceId: String
    let syncStatusRawValue: String

    init(_ item: TonightDinnerOption) {
        id = item.id
        title = item.title
        note = item.note
        statusRawValue = item.status.rawValue
        createdAt = item.createdAt
        decidedAt = item.decidedAt
        createdByUserId = item.createdByUserId
        spaceId = item.spaceId
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: TonightDinnerOption {
        TonightDinnerOption(
            id: id,
            title: title,
            note: note,
            status: TonightDinnerStatus(rawValue: statusRawValue) ?? .candidate,
            createdAt: createdAt,
            decidedAt: decidedAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

private struct StoredRemoteRitual: Codable {
    let id: UUID
    let title: String
    let kindRawValue: String
    let isCompleted: Bool
    let note: String
    let createdAt: Date
    let updatedAt: Date
    let createdByUserId: String
    let spaceId: String
    let syncStatusRawValue: String

    init(_ item: RitualItem) {
        id = item.id
        title = item.title
        kindRawValue = item.kind.rawValue
        isCompleted = item.isCompleted
        note = item.note
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        createdByUserId = item.createdByUserId
        spaceId = item.spaceId
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: RitualItem {
        RitualItem(
            id: id,
            title: title,
            kind: RitualKind(rawValue: kindRawValue) ?? .promise,
            isCompleted: isCompleted,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}

private struct StoredRemoteCurrentStatus: Codable {
    let id: UUID
    let userId: String
    let displayText: String
    let toneRawValue: String
    let effectiveScopeRawValue: String
    let spaceId: String
    let updatedAt: Date

    init(_ item: CurrentStatusItem) {
        id = item.id
        userId = item.userId
        displayText = item.displayText
        toneRawValue = item.tone.rawValue
        effectiveScopeRawValue = item.effectiveScope.rawValue
        spaceId = item.spaceId
        updatedAt = item.updatedAt
    }

    var model: CurrentStatusItem {
        CurrentStatusItem(
            id: id,
            userId: userId,
            displayText: displayText,
            tone: StatusTone(rawValue: toneRawValue) ?? .softGreen,
            effectiveScope: CurrentStatusEffectiveScope(rawValue: effectiveScopeRawValue) ?? .today,
            spaceId: spaceId,
            updatedAt: updatedAt
        )
    }
}

private struct StoredRemoteWhisperNote: Codable {
    let id: UUID
    let content: String
    let createdAt: Date
    let createdByUserId: String
    let spaceId: String
    let syncStatusRawValue: String

    init(_ item: WhisperNoteItem) {
        id = item.id
        content = item.content
        createdAt = item.createdAt
        createdByUserId = item.createdByUserId
        spaceId = item.spaceId
        syncStatusRawValue = item.syncStatus.rawValue
    }

    var model: WhisperNoteItem {
        WhisperNoteItem(
            id: id,
            content: content,
            createdAt: createdAt,
            createdByUserId: createdByUserId,
            spaceId: spaceId,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue) ?? .localOnly
        )
    }
}
