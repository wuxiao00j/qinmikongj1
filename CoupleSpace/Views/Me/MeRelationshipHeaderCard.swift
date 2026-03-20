import SwiftUI

struct MeRelationshipHeaderCard: View {
    let relationship: CoupleRelationshipState
    let accountDisplayName: String
    let accountDetailText: String?
    let onLogout: () -> Void
    let onCreateSpace: () -> Void
    let onJoinSpace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeroLabel(text: heroLabelText, systemImage: relationship.relationStatus.symbol)

            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: -12) {
                    avatar(text: relationship.currentUser.initials, isHighlighted: false, isDimmed: false)
                    avatar(
                        text: relationship.partner?.initials ?? "+",
                        isHighlighted: relationship.isBound,
                        isDimmed: !relationship.isBound
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(titleText)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                label(text: relationship.relationStatus.label, systemImage: relationship.relationStatus.symbol)

                if let metaText {
                    label(text: metaText, systemImage: metaSymbol)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.subtitle)

                    Text(statusValue)
                        .font(.system(size: relationship.isBound ? 28 : 26, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.title)
                }

                Spacer(minLength: 0)
            }

            if relationship.relationStatus == .unpaired {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Button(action: onCreateSpace) {
                            PageCTAButton(text: "创建共享空间", systemImage: "heart")
                        }
                        .buttonStyle(.plain)

                        Button(action: onJoinSpace) {
                            PageActionPill(text: "输入邀请码加入", systemImage: "number")
                        }
                        .buttonStyle(.plain)
                    }

                    Text("这两个入口会继续走同一条关系设置流程：先创建邀请码，或输入已经拿到的邀请码加入。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(3)
                }
            }

            accountStatusCard
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.glow.opacity(0.36))
                    .frame(width: 190, height: 190)
                    .blur(radius: 28)
                    .offset(x: 120, y: -70)

                Circle()
                    .fill(AppTheme.Colors.softAccentSecondary.opacity(0.22))
                    .frame(width: 140, height: 140)
                    .blur(radius: 18)
                    .offset(x: -100, y: 90)
            }
        )
        .appCardSurface(
            AppTheme.Colors.cardSurfaceGradient(.primary, accent: AppTheme.Colors.softAccent),
            cornerRadius: 28,
            borderColor: AppTheme.Colors.divider
        )
    }

    private var heroLabelText: String {
        switch relationship.relationStatus {
        case .unpaired:
            return "共享空间关系"
        case .inviting:
            return "余白邀请"
        case .paired:
            return "双人共享空间"
        }
    }

    private var titleText: String {
        switch relationship.relationStatus {
        case .unpaired:
            return "还没有开始共享空间"
        case .inviting:
            return "\(relationship.currentUser.nickname) 正在邀请 \(relationship.partnerDisplayName)"
        case .paired:
            return "\(relationship.currentUser.nickname) & \(relationship.partnerDisplayName)"
        }
    }

    private var subtitleText: String {
        switch relationship.relationStatus {
        case .unpaired:
            return "先创建一份余白，或者输入邀请码加入对方的空间，关系状态就会在这里安静地出现。"
        case .inviting:
            return "邀请码已经生成，等 \(relationship.partnerDisplayName) 加入后，这个空间就会正式变成两个人共享。"
        case .paired:
            return "你们已经进入同一个共享空间，回忆、愿望和纪念都会以双人关系继续沉淀。"
        }
    }

    private var statusTitle: String {
        switch relationship.relationStatus {
        case .unpaired:
            return "当前状态"
        case .inviting:
            return "当前状态"
        case .paired:
            return "共享状态"
        }
    }

    private var statusValue: String {
        switch relationship.relationStatus {
        case .unpaired:
            return "未绑定"
        case .inviting:
            return "邀请中"
        case .paired:
            return "已激活"
        }
    }

    private var metaText: String? {
        switch relationship.relationStatus {
        case .unpaired:
            return "可创建或加入"
        case .inviting:
            return relationship.inviteCode
        case .paired:
            return relationship.space?.createdText
        }
    }

    private var metaSymbol: String {
        switch relationship.relationStatus {
        case .unpaired:
            return "sparkles"
        case .inviting:
            return "number"
        case .paired:
            return "sparkles"
        }
    }

    private func avatar(text: String, isHighlighted: Bool, isDimmed: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    isHighlighted
                    ? AppTheme.Colors.softAccent
                    : AppTheme.Colors.cardSurface(isDimmed ? .tertiary : .secondary)
                )

            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.title)
        }
        .frame(width: 54, height: 54)
        .overlay(
            Circle()
                .stroke(isDimmed ? AppTheme.Colors.divider.opacity(0.9) : Color.white.opacity(0.92), lineWidth: 3)
        )
        .opacity(isDimmed ? 0.78 : 1)
    }

    private func label(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(AppTheme.Colors.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.Colors.cardSurface(.tertiary))
        .clipShape(Capsule())
    }

    private var accountStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前账号")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.subtitle)

                    Text(accountDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    if let accountDetailText,
                       accountDetailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(accountDetailText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                            .lineSpacing(3)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onLogout) {
                    PageActionPill(
                        text: "退出登录",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
                .buttonStyle(.plain)
            }

            Text("账号会继续承接当前关系和共享空间；如需切换账号，可以先从这里退出。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardSurface(.secondary))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
