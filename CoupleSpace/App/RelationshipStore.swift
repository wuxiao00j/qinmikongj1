import Foundation

enum CoupleRelationStatus: String, Codable {
    case unpaired
    case inviting
    case paired

    var label: String {
        switch self {
        case .unpaired:
            return "未绑定"
        case .inviting:
            return "邀请中"
        case .paired:
            return "已绑定"
        }
    }

    var symbol: String {
        switch self {
        case .unpaired:
            return "person.badge.plus"
        case .inviting:
            return "paperplane"
        case .paired:
            return "heart.fill"
        }
    }
}

enum RelationshipConnectionMode: String, Codable {
    case localDemo
    case backendRemote
}

struct RelationshipUser: Codable, Equatable {
    let userId: String
    var nickname: String
    var initials: String
}

struct SharedSpaceState: Codable, Equatable {
    let spaceId: String
    var title: String
    var inviteCode: String
    var isActivated: Bool
    var createdAt: Date

    var createdText: String {
        Self.createdFormatter.string(from: createdAt)
    }

    private static let createdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "空间建立于 yyyy.MM"
        return formatter
    }()
}

struct CoupleRelationshipState: Codable, Equatable {
    var currentAccountId: String?
    var currentUser: RelationshipUser
    var partner: RelationshipUser?
    var space: SharedSpaceState?
    var relationStatus: CoupleRelationStatus
    var connectionMode: RelationshipConnectionMode
    var inviteCode: String?
    var invitedAt: Date?
    var pairedAt: Date?

    static let demoDefault = CoupleRelationshipState(
        currentAccountId: nil,
        currentUser: RelationshipUser(
            userId: "user-local",
            nickname: "我",
            initials: "我"
        ),
        partner: nil,
        space: nil,
        relationStatus: .unpaired,
        connectionMode: .localDemo,
        inviteCode: nil,
        invitedAt: nil,
        pairedAt: nil
    )

    private enum CodingKeys: String, CodingKey {
        case currentAccountId
        case currentUser
        case partner
        case space
        case relationStatus
        case connectionMode
        case inviteCode
        case invitedAt
        case pairedAt
    }

    init(
        currentAccountId: String?,
        currentUser: RelationshipUser,
        partner: RelationshipUser?,
        space: SharedSpaceState?,
        relationStatus: CoupleRelationStatus,
        connectionMode: RelationshipConnectionMode,
        inviteCode: String?,
        invitedAt: Date?,
        pairedAt: Date?
    ) {
        self.currentAccountId = currentAccountId
        self.currentUser = currentUser
        self.partner = partner
        self.space = space
        self.relationStatus = relationStatus
        self.connectionMode = connectionMode
        self.inviteCode = inviteCode
        self.invitedAt = invitedAt
        self.pairedAt = pairedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentAccountId = try container.decodeIfPresent(String.self, forKey: .currentAccountId)
        currentUser = try container.decode(RelationshipUser.self, forKey: .currentUser)
        partner = try container.decodeIfPresent(RelationshipUser.self, forKey: .partner)
        space = try container.decodeIfPresent(SharedSpaceState.self, forKey: .space)
        relationStatus = try container.decode(CoupleRelationStatus.self, forKey: .relationStatus)
        connectionMode = try container.decodeIfPresent(RelationshipConnectionMode.self, forKey: .connectionMode) ?? .localDemo
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        invitedAt = try container.decodeIfPresent(Date.self, forKey: .invitedAt)
        pairedAt = try container.decodeIfPresent(Date.self, forKey: .pairedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentAccountId, forKey: .currentAccountId)
        try container.encode(currentUser, forKey: .currentUser)
        try container.encodeIfPresent(partner, forKey: .partner)
        try container.encodeIfPresent(space, forKey: .space)
        try container.encode(relationStatus, forKey: .relationStatus)
        try container.encode(connectionMode, forKey: .connectionMode)
        try container.encodeIfPresent(inviteCode, forKey: .inviteCode)
        try container.encodeIfPresent(invitedAt, forKey: .invitedAt)
        try container.encodeIfPresent(pairedAt, forKey: .pairedAt)
    }
}

struct AppContentScope: Equatable {
    let currentUserId: String
    let partnerUserId: String?
    let spaceId: String
    let isSharedSpace: Bool
}

enum JoinSpaceResult: Equatable {
    case success
    case invalidInviteCode

    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .invalidInviteCode:
            return "还没有识别到这个邀请码，请确认对方已经先创建共享空间，并把完整邀请码发给你。"
        }
    }
}

private struct InviteCodeRecord: Codable, Equatable {
    let inviteCode: String
    let spaceId: String
    let spaceTitle: String
    let ownerUserId: String
    let ownerNickname: String
    let createdAt: Date
}

extension CoupleRelationshipState {
    var isBound: Bool {
        relationStatus == .paired
    }

    var hasPendingInvite: Bool {
        relationStatus == .inviting
    }

    var partnerDisplayName: String {
        partner?.nickname ?? "对方"
    }

    var isUsingBackendConnection: Bool {
        connectionMode == .backendRemote
    }

    var spaceDisplayTitle: String {
        space?.title ?? "双人共享空间"
    }

    var contentScope: AppContentScope {
        AppContentScope(
            currentUserId: currentUser.userId,
            partnerUserId: partner?.userId,
            spaceId: space?.spaceId ?? AppDataDefaults.localSpaceId,
            isSharedSpace: relationStatus == .paired
        )
    }
}

enum RelationshipActionError: LocalizedError, Equatable {
    case backendUnavailable
    case unauthorized
    case invalidInviteCode
    case spaceFull
    case activeSpaceExists
    case accountUnavailable
    case backendRequestFailed(message: String)
    case responseDecodingFailed

    var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "当前暂时连不上测试环境，请确认当前网络可用。"
        case .unauthorized:
            return "当前账号状态已经失效，请重新登录后再试。"
        case .invalidInviteCode:
            return "还没有识别到这个邀请码，请确认对方已经先创建共享空间，并把完整邀请码发给你。"
        case .spaceFull:
            return "这个共享空间已经有两位成员了，暂时不能再加入。"
        case .activeSpaceExists:
            return "当前账号已经在另一个共享空间里，暂时不能再创建或加入新的空间。"
        case .accountUnavailable:
            return "还没有识别到可用账号，请先完成登录后再试。"
        case .backendRequestFailed(let message):
            return message
        case .responseDecodingFailed:
            return "后端返回了无法识别的关系结果，请稍后再试。"
        }
    }
}

private struct RelationshipBackendErrorEnvelope: Decodable {
    let error: RelationshipBackendErrorBody
}

private struct RelationshipBackendErrorBody: Decodable {
    let code: String
    let message: String
}

private struct RelationshipBackendSpacePayload: Decodable {
    let spaceId: String
    let title: String
    let inviteCode: String
    let isActivated: Bool
    let memberCount: Int
    let currentRole: String
    let relationStatus: String
    let currentAccountId: String
    let currentUserId: String
    let partnerAccountId: String?
    let partnerUserId: String?
}

private struct RelationshipBackendClient {
    let configuration: LocalBackendConnectionConfiguration
    let session: URLSession

    init(
        configuration: LocalBackendConnectionConfiguration = .current,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func createSpace(
        title: String,
        sessionState: AccountSessionState
    ) async throws -> RelationshipBackendSpacePayload {
        try await sendRequest(
            pathComponents: ["spaces"],
            sessionState: sessionState,
            requestBody: ["title": title]
        )
    }

    func joinSpace(
        inviteCode: String,
        sessionState: AccountSessionState
    ) async throws -> RelationshipBackendSpacePayload {
        try await sendRequest(
            pathComponents: ["spaces", "join"],
            sessionState: sessionState,
            requestBody: ["inviteCode": inviteCode]
        )
    }

    func fetchSpaceStatus(
        spaceId: String,
        sessionState: AccountSessionState
    ) async throws -> RelationshipBackendSpacePayload {
        guard let baseURL = configuration.baseURL else {
            throw RelationshipActionError.backendUnavailable
        }

        guard let account = sessionState.account,
              let authorization = sessionState.authorization,
              sessionState.sessionSource == .authenticated else {
            throw RelationshipActionError.unauthorized
        }

        var url = baseURL
        url.appendPathComponent("spaces")
        url.appendPathComponent(spaceId)

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(account.accountId, forHTTPHeaderField: "X-CoupleSpace-Account-ID")
        request.setValue(account.accountId, forHTTPHeaderField: "X-CoupleSpace-Session-Account-ID")
        request.setValue("Bearer \(authorization.accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotConnectToHost, .timedOut, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw RelationshipActionError.backendUnavailable
            default:
                throw RelationshipActionError.backendRequestFailed(message: "这次没有连上关系服务：\(urlError.localizedDescription)")
            }
        } catch {
            throw RelationshipActionError.backendRequestFailed(message: "这次没有连上关系服务：\(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RelationshipActionError.responseDecodingFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapBackendError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()

        do {
            return try decoder.decode(RelationshipBackendSpacePayload.self, from: data)
        } catch {
            throw RelationshipActionError.responseDecodingFailed
        }
    }

    private func sendRequest(
        pathComponents: [String],
        sessionState: AccountSessionState,
        requestBody: [String: String]
    ) async throws -> RelationshipBackendSpacePayload {
        guard let baseURL = configuration.baseURL else {
            throw RelationshipActionError.backendUnavailable
        }

        guard let account = sessionState.account,
              let authorization = sessionState.authorization,
              sessionState.sessionSource == .authenticated else {
            throw RelationshipActionError.unauthorized
        }

        var url = baseURL
        for component in pathComponents {
            url.appendPathComponent(component)
        }

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw RelationshipActionError.backendRequestFailed(message: "这次没有成功整理关系请求。")
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(account.accountId, forHTTPHeaderField: "X-CoupleSpace-Account-ID")
        request.setValue(account.accountId, forHTTPHeaderField: "X-CoupleSpace-Session-Account-ID")
        request.setValue("Bearer \(authorization.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotConnectToHost, .timedOut, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw RelationshipActionError.backendUnavailable
            default:
                throw RelationshipActionError.backendRequestFailed(message: "这次没有连上关系服务：\(urlError.localizedDescription)")
            }
        } catch {
            throw RelationshipActionError.backendRequestFailed(message: "这次没有连上关系服务：\(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RelationshipActionError.responseDecodingFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapBackendError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(RelationshipBackendSpacePayload.self, from: data)
        } catch {
            throw RelationshipActionError.responseDecodingFailed
        }
    }

    private func mapBackendError(data: Data, statusCode: Int) -> RelationshipActionError {
        if let envelope = try? JSONDecoder().decode(RelationshipBackendErrorEnvelope.self, from: data) {
            switch envelope.error.code {
            case "invite_not_found", "invalid_invite_code":
                return .invalidInviteCode
            case "space_full":
                return .spaceFull
            case "active_space_exists":
                return .activeSpaceExists
            case "unauthorized", "account_mismatch", "session_account_mismatch":
                return .unauthorized
            case "account_not_found":
                return .accountUnavailable
            default:
                return .backendRequestFailed(message: envelope.error.message)
            }
        }

        if statusCode == 401 {
            return .unauthorized
        }

        return .backendRequestFailed(message: "关系请求返回了异常状态码 \(statusCode)。")
    }
}

extension CoupleRelationStatus {
    init(remoteRelationStatus: String, isActivated: Bool) {
        switch remoteRelationStatus {
        case "paired":
            self = .paired
        case "invited":
            self = isActivated ? .paired : .inviting
        default:
            self = isActivated ? .paired : .unpaired
        }
    }
}

@MainActor
final class RelationshipStore: ObservableObject {
    @Published private(set) var state: CoupleRelationshipState

    private let defaults: UserDefaults
    private let accountSessionStore: AccountSessionStore
    private let storageKey = "com.barry.CoupleSpace.relationshipState"
    private let inviteRecordsStorageKey = "com.barry.CoupleSpace.relationshipInviteRecords"
    private let backendClient: RelationshipBackendClient

    init(
        defaults: UserDefaults = .standard,
        accountSessionStore: AccountSessionStore
    ) {
        self.defaults = defaults
        self.accountSessionStore = accountSessionStore
        self.backendClient = RelationshipBackendClient()

        if let data = defaults.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                state = try decoder.decode(CoupleRelationshipState.self, from: data)
                return
            } catch {
                defaults.removeObject(forKey: storageKey)
            }
        }

        state = .demoDefault
    }

    func createSpace(currentNickname: String, partnerNickname: String) async throws {
        let currentName = Self.normalizedName(
            currentNickname,
            fallback: accountSessionStore.state.account?.nickname ?? state.currentUser.nickname
        )
        let partnerName = Self.normalizedName(partnerNickname, fallback: "对方")
        let sessionState = try ensureAuthenticatedSession()
        let spaceTitle = "\(currentName) 和 \(partnerName) 的共享空间"
        let payload = try await backendClient.createSpace(title: spaceTitle, sessionState: sessionState)
        let invitedAt = Date()

        state = CoupleRelationshipState(
            currentAccountId: payload.currentAccountId,
            currentUser: Self.makeUser(id: payload.currentUserId, nickname: currentName),
            partner: Self.makeUser(
                id: payload.partnerUserId ?? "pending-\(payload.inviteCode.lowercased())",
                nickname: partnerName
            ),
            space: SharedSpaceState(
                spaceId: payload.spaceId,
                title: payload.title,
                inviteCode: payload.inviteCode,
                isActivated: payload.isActivated,
                createdAt: invitedAt
            ),
            relationStatus: CoupleRelationStatus(
                remoteRelationStatus: payload.relationStatus,
                isActivated: payload.isActivated
            ),
            connectionMode: .backendRemote,
            inviteCode: payload.inviteCode,
            invitedAt: invitedAt,
            pairedAt: payload.isActivated ? invitedAt : nil
        )
        save()
        await refreshRemoteRelationshipStatusIfNeeded()
    }

    func joinSpace(currentNickname: String, partnerNickname: String, inviteCode: String) async throws {
        let normalizedCode = Self.normalizedInviteCode(inviteCode)
        let currentName = Self.normalizedName(
            currentNickname,
            fallback: accountSessionStore.state.account?.nickname ?? state.currentUser.nickname
        )
        let sessionState = try ensureAuthenticatedSession()
        let payload = try await backendClient.joinSpace(inviteCode: normalizedCode, sessionState: sessionState)
        let partnerName = Self.normalizedName(partnerNickname, fallback: state.partner?.nickname ?? "对方")
        let now = Date()

        state = CoupleRelationshipState(
            currentAccountId: payload.currentAccountId,
            currentUser: Self.makeUser(id: payload.currentUserId, nickname: currentName),
            partner: payload.partnerUserId.map { Self.makeUser(id: $0, nickname: partnerName) },
            space: SharedSpaceState(
                spaceId: payload.spaceId,
                title: payload.title,
                inviteCode: payload.inviteCode,
                isActivated: payload.isActivated,
                createdAt: state.space?.createdAt ?? state.invitedAt ?? now
            ),
            relationStatus: CoupleRelationStatus(
                remoteRelationStatus: payload.relationStatus,
                isActivated: payload.isActivated
            ),
            connectionMode: .backendRemote,
            inviteCode: payload.inviteCode,
            invitedAt: state.invitedAt ?? now,
            pairedAt: payload.isActivated ? now : nil
        )
        save()
        await refreshRemoteRelationshipStatusIfNeeded()
    }

    func createLocalDemoSpace(currentNickname: String, partnerNickname: String) {
        let currentName = Self.normalizedName(currentNickname, fallback: state.currentUser.nickname)
        let partnerName = Self.normalizedName(partnerNickname, fallback: "对方")
        let inviteCode = Self.makeInviteCode()
        let createdAt = Date()
        let spaceId = "space-\(UUID().uuidString.prefix(8))"
        let spaceTitle = "\(currentName) & \(partnerName)"

        saveInviteRecord(
            InviteCodeRecord(
                inviteCode: inviteCode,
                spaceId: spaceId,
                spaceTitle: spaceTitle,
                ownerUserId: "partner-\(inviteCode.lowercased())",
                ownerNickname: currentName,
                createdAt: createdAt
            )
        )

        state = CoupleRelationshipState(
            currentAccountId: nil,
            currentUser: Self.makeUser(id: state.currentUser.userId, nickname: currentName),
            partner: Self.makeUser(id: "pending-\(UUID().uuidString)", nickname: partnerName),
            space: SharedSpaceState(
                spaceId: spaceId,
                title: spaceTitle,
                inviteCode: inviteCode,
                isActivated: false,
                createdAt: createdAt
            ),
            relationStatus: .inviting,
            connectionMode: .localDemo,
            inviteCode: inviteCode,
            invitedAt: createdAt,
            pairedAt: nil
        )
        save()
    }

    func joinLocalDemoSpace(currentNickname: String, partnerNickname: String, inviteCode: String) -> JoinSpaceResult {
        let normalizedCode = Self.normalizedInviteCode(inviteCode)
        guard let inviteRecord = inviteRecord(for: normalizedCode) else {
            return .invalidInviteCode
        }

        let currentName = Self.normalizedName(currentNickname, fallback: state.currentUser.nickname)
        let partnerName = Self.normalizedName(partnerNickname, fallback: inviteRecord.ownerNickname)
        let pairedAt = Date()

        state = CoupleRelationshipState(
            currentAccountId: nil,
            currentUser: Self.makeUser(id: state.currentUser.userId, nickname: currentName),
            partner: Self.makeUser(id: inviteRecord.ownerUserId, nickname: partnerName),
            space: SharedSpaceState(
                spaceId: inviteRecord.spaceId,
                title: inviteRecord.spaceTitle,
                inviteCode: normalizedCode,
                isActivated: true,
                createdAt: inviteRecord.createdAt
            ),
            relationStatus: .paired,
            connectionMode: .localDemo,
            inviteCode: normalizedCode,
            invitedAt: inviteRecord.createdAt,
            pairedAt: pairedAt
        )
        save()
        return .success
    }

    func completeInvitation() {
        guard state.relationStatus == .inviting, state.connectionMode == .localDemo else { return }

        state.relationStatus = .paired
        state.space?.isActivated = true
        state.pairedAt = Date()
        save()
    }

    func resetDemo() {
        state = .demoDefault
        save()
    }

    func restoreFromBackup(_ restoredState: CoupleRelationshipState) {
        state = restoredState
        save()
    }

    var contentScope: AppContentScope {
        state.contentScope
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save relationship state: \(error)")
        }
    }

    private func inviteRecord(for inviteCode: String) -> InviteCodeRecord? {
        loadInviteRecords().first(where: { $0.inviteCode == inviteCode })
    }

    private func loadInviteRecords() -> [InviteCodeRecord] {
        guard let data = defaults.data(forKey: inviteRecordsStorageKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([InviteCodeRecord].self, from: data)
        } catch {
            defaults.removeObject(forKey: inviteRecordsStorageKey)
            return []
        }
    }

    private func saveInviteRecord(_ record: InviteCodeRecord) {
        var records = loadInviteRecords()
        records.removeAll { $0.inviteCode == record.inviteCode }
        records.append(record)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            defaults.set(data, forKey: inviteRecordsStorageKey)
        } catch {
            assertionFailure("Failed to save invite records: \(error)")
        }
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }

    private static func normalizedInviteCode(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? makeInviteCode() : trimmed
    }

    private static func normalizedName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func makeUser(id: String, nickname: String) -> RelationshipUser {
        RelationshipUser(
            userId: id,
            nickname: nickname,
            initials: String(nickname.prefix(1)).uppercased()
        )
    }

    func adoptAuthenticatedRelationship(activeSpaceID: String?) async {
        let sessionState = accountSessionStore.state
        guard let account = sessionState.account else { return }

        let currentNickname = Self.normalizedName(
            account.nickname,
            fallback: state.currentUser.nickname
        )
        let normalizedActiveSpaceID = activeSpaceID?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedActiveSpaceID, normalizedActiveSpaceID.isEmpty == false {
            state = CoupleRelationshipState(
                currentAccountId: account.accountId,
                currentUser: Self.makeUser(
                    id: state.currentUser.userId,
                    nickname: currentNickname
                ),
                partner: state.partner,
                space: SharedSpaceState(
                    spaceId: normalizedActiveSpaceID,
                    title: state.space?.title ?? "双人共享空间",
                    inviteCode: state.space?.inviteCode ?? "",
                    isActivated: true,
                    createdAt: state.space?.createdAt ?? state.pairedAt ?? Date()
                ),
                relationStatus: .paired,
                connectionMode: .backendRemote,
                inviteCode: state.inviteCode,
                invitedAt: state.invitedAt,
                pairedAt: state.pairedAt ?? Date()
            )
            save()
            await refreshRemoteRelationshipStatusIfNeeded()
            return
        }

        state = CoupleRelationshipState(
            currentAccountId: account.accountId,
            currentUser: Self.makeUser(
                id: AppDataDefaults.localUserId,
                nickname: currentNickname
            ),
            partner: nil,
            space: nil,
            relationStatus: .unpaired,
            connectionMode: .localDemo,
            inviteCode: nil,
            invitedAt: nil,
            pairedAt: nil
        )
        save()
    }

    private func ensureAuthenticatedSession() throws -> AccountSessionState {
        let sessionState = accountSessionStore.state

        guard sessionState.sessionSource == .authenticated,
              sessionState.account != nil else {
            throw RelationshipActionError.accountUnavailable
        }

        guard let authorization = sessionState.authorization,
              authorization.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw RelationshipActionError.unauthorized
        }

        return sessionState
    }

    func refreshRemoteRelationshipStatusIfNeeded() async {
        guard state.connectionMode == .backendRemote,
              let space = state.space else {
            return
        }

        let sessionState: AccountSessionState
        do {
            sessionState = try ensureAuthenticatedSession()
        } catch {
            return
        }

        let payload: RelationshipBackendSpacePayload
        do {
            payload = try await backendClient.fetchSpaceStatus(
                spaceId: space.spaceId,
                sessionState: sessionState
            )
        } catch {
            return
        }

        applyRefreshedRelationshipStatus(payload)
    }

    private func applyRefreshedRelationshipStatus(_ payload: RelationshipBackendSpacePayload) {
        let refreshedStatus = CoupleRelationStatus(
            remoteRelationStatus: payload.relationStatus,
            isActivated: payload.isActivated
        )

        var nextState = state
        var hasChanges = false

        if nextState.currentAccountId != payload.currentAccountId {
            nextState.currentAccountId = payload.currentAccountId
            hasChanges = true
        }

        if nextState.currentUser.userId != payload.currentUserId {
            nextState.currentUser = Self.makeUser(
                id: payload.currentUserId,
                nickname: nextState.currentUser.nickname
            )
            hasChanges = true
        }

        if nextState.relationStatus != refreshedStatus {
            nextState.relationStatus = refreshedStatus
            hasChanges = true
        }

        let refreshedSpace = SharedSpaceState(
            spaceId: payload.spaceId,
            title: payload.title,
            inviteCode: payload.inviteCode,
            isActivated: payload.isActivated,
            createdAt: nextState.space?.createdAt ?? nextState.invitedAt ?? nextState.pairedAt ?? Date()
        )

        if nextState.space != refreshedSpace {
            nextState.space = refreshedSpace
            hasChanges = true
        }

        if nextState.connectionMode != .backendRemote {
            nextState.connectionMode = .backendRemote
            hasChanges = true
        }

        if let partnerUserId = payload.partnerUserId,
           partnerUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let normalizedPartnerNickname = Self.normalizedName(
                nextState.partner?.nickname ?? "",
                fallback: "对方"
            )
            let refreshedPartner = Self.makeUser(
                id: partnerUserId,
                nickname: normalizedPartnerNickname
            )

            if nextState.partner != refreshedPartner {
                nextState.partner = refreshedPartner
                hasChanges = true
            }
        }

        if refreshedStatus == .paired {
            let resolvedPairedAt = nextState.pairedAt ?? Date()
            if nextState.pairedAt != resolvedPairedAt {
                nextState.pairedAt = resolvedPairedAt
                hasChanges = true
            }
        }

        guard hasChanges else { return }
        state = nextState
        save()
    }
}
