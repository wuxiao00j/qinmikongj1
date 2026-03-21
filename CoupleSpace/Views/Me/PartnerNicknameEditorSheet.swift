import SwiftUI

struct PartnerNicknameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var relationshipStore: RelationshipStore

    @State private var currentNickname = ""
    @State private var partnerNickname = ""
    @State private var lastResetKey: EditorDraftResetKey?

    var body: some View {
        NavigationStack {
            ZStack {
                AppAtmosphereBackground(
                    primaryGlow: AppTheme.Colors.softAccent.opacity(0.22),
                    secondaryGlow: AppTheme.Colors.glow.opacity(0.16),
                    primaryOffset: CGSize(width: -120, height: -235),
                    secondaryOffset: CGSize(width: 120, height: -36)
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.pageBlock) {
                        AppFeatureCard(
                            title: "双人资料",
                            subtitle: "只改这台设备上的显示方式，不会同步到空间。",
                            symbol: "character.textbox",
                            accent: AppTheme.Colors.softAccent
                        ) {
                            WrappedPillStack(
                                items: [
                                    WrappedPillItem(text: "按空间隔离", systemImage: "square.stack.3d.down.right"),
                                    WrappedPillItem(text: "仅本机可见", systemImage: "iphone")
                                ]
                            )
                        }

                        AppSectionCard(
                            title: "本地备注名",
                            subtitle: "不改真实昵称，只覆盖当前空间里的 UI 展示。",
                            symbol: "pencil.line"
                        ) {
                            VStack(spacing: 14) {
                                nicknameField(
                                    title: "你的备注名",
                                    text: $currentNickname,
                                    placeholder: relationshipStore.currentUserDisplayName,
                                    note: "默认昵称：\(relationshipStore.state.currentUser.nickname)"
                                )

                                nicknameField(
                                    title: "对方备注名",
                                    text: $partnerNickname,
                                    placeholder: relationshipStore.partnerDisplayNameResolved,
                                    note: "默认昵称：\(relationshipStore.state.partnerDisplayName)"
                                )
                            }
                        }

                        VStack(spacing: 10) {
                            Button {
                                saveOverrides()
                            } label: {
                                saveButtonLabel
                            }
                            .buttonStyle(.plain)

                            Button {
                                restoreDefaults()
                            } label: {
                                secondaryButtonLabel(
                                    title: "恢复默认",
                                    systemImage: "arrow.uturn.backward"
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                dismiss()
                            } label: {
                                secondaryButtonLabel(
                                    title: "取消",
                                    systemImage: "xmark"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AppTheme.Spacing.page)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("双人资料")
            .secondaryPageNavigationStyle()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            syncDrafts(for: draftResetKey, force: true)
        }
        .onChange(of: draftResetKey) { _, nextKey in
            syncDrafts(for: nextKey)
        }
    }

    private var saveButtonLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))

            Text("保存")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Colors.title)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .fill(AppTheme.Colors.cardSurfaceGradient(.tertiary, accent: AppTheme.Colors.softAccent))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .stroke(AppTheme.Colors.divider, lineWidth: 1)
        }
    }

    private func secondaryButtonLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(title)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(AppTheme.Colors.deepAccent)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
        }
    }

    private func nicknameField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.title)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.cardSurface(.secondary))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                        .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                }

            Text(note)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
    }

    private func saveOverrides() {
        saveOverride(
            currentNickname,
            save: relationshipStore.setCurrentUserNicknameOverride,
            clear: relationshipStore.clearCurrentUserNicknameOverride,
            defaultValue: relationshipStore.state.currentUser.nickname
        )
        saveOverride(
            partnerNickname,
            save: relationshipStore.setPartnerNicknameOverride,
            clear: relationshipStore.clearPartnerNicknameOverride,
            defaultValue: relationshipStore.state.partnerDisplayName
        )
        dismiss()
    }

    private func restoreDefaults() {
        relationshipStore.clearCurrentUserNicknameOverride()
        relationshipStore.clearPartnerNicknameOverride()
        dismiss()
    }

    private func saveOverride(
        _ value: String,
        save: (String) -> Void,
        clear: () -> Void,
        defaultValue: String
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty || trimmed == defaultValue {
            clear()
        } else {
            save(trimmed)
        }
    }

    private var draftResetKey: EditorDraftResetKey {
        EditorDraftResetKey(
            activeSpaceId: relationshipStore.state.space?.spaceId,
            currentUserId: relationshipStore.state.currentUser.userId,
            currentAccountId: relationshipStore.state.currentUser.accountId,
            partnerUserId: relationshipStore.state.partner?.userId,
            partnerAccountId: relationshipStore.state.partner?.accountId
        )
    }

    private func syncDrafts(for key: EditorDraftResetKey, force: Bool = false) {
        guard force || lastResetKey != key else { return }
        currentNickname = relationshipStore.currentUserDisplayName
        partnerNickname = relationshipStore.partnerDisplayNameResolved
        lastResetKey = key
    }
}

private struct EditorDraftResetKey: Equatable {
    let activeSpaceId: String?
    let currentUserId: String
    let currentAccountId: String?
    let partnerUserId: String?
    let partnerAccountId: String?
}
