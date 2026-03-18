import SwiftUI

struct HomeCoupleHeaderCard: View {
    let couple: HomeCouple
    let milestoneText: String
    let currentUserStatus: DailyStatus?
    let partnerStatus: DailyStatus?
    let sharedStatus: HomeSharedStatus
    let myStatusActionTitle: String
    let onEditMyStatus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.hero) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeroLabel(text: "情侣空间", systemImage: "heart.fill")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(couple.first.name)
                            .font(.system(size: 31, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.title)

                        Text("&")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.deepAccent.opacity(0.82))
                            .padding(.leading, 1)

                        Text(couple.second.name)
                            .font(.system(size: 31, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.title)
                    }
                }

                Spacer(minLength: 0)

                HStack(alignment: .top, spacing: 10) {
                    personStatusUnit(
                        partner: couple.first,
                        status: currentUserStatus,
                        fallbackTone: .mistBlue,
                        fallbackText: "写句近况",
                        isHighlighted: false
                    )

                    personStatusUnit(
                        partner: couple.second,
                        status: partnerStatus,
                        fallbackTone: .powderPink,
                        fallbackText: "等对方写近况",
                        isHighlighted: true
                    )
                }
                .padding(.top, 4)
            }

            HStack(spacing: 10) {
                PageStatTile(
                    title: "今天",
                    value: Self.dateFormatter.string(from: .now)
                )

                PageStatTile(
                    title: "在一起",
                    value: couple.relationshipDays > 0 ? "\(couple.relationshipDays) 天" : "刚开始"
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(AppTheme.Colors.statusTone(sharedStatus.tone))
                        .frame(width: 9, height: 9)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sharedStatus.summary)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.title)
                            .lineSpacing(3)

                        Text(sharedStatus.updatedText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.subtitle)
                    }

                    Spacer(minLength: 0)
                }

                Button(action: onEditMyStatus) {
                    PageActionPill(text: myStatusActionTitle, systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))

                Text(milestoneText)
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(AppTheme.Colors.deepAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.5))
            .clipShape(Capsule())

            Text(couple.note)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.glow.opacity(0.55))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .offset(x: 110, y: -70)

                Circle()
                    .fill(AppTheme.Colors.softAccent.opacity(0.4))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                    .offset(x: -120, y: 110)
            }
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepAccent.opacity(0.5))
                .padding(18)
        }
        .appCardSurface(
            LinearGradient(
                colors: [
                    Color.white,
                    AppTheme.Colors.softAccent.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            cornerRadius: AppTheme.CornerRadius.hero,
            borderColor: AppTheme.Colors.divider
        )
    }

    private func avatar(initials: String, ringColor: Color, isHighlighted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(ringColor.opacity(0.22))
                .frame(width: 64, height: 64)

            Circle()
                .fill(
                    isHighlighted
                    ? AppTheme.Colors.softAccent
                    : AppTheme.Colors.secondaryCardBackground
                )

            Text(initials)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.title)
        }
        .frame(width: 58, height: 58)
        .overlay(
            Circle()
                .stroke(ringColor.opacity(0.95), lineWidth: 3)
        )
        .shadow(color: ringColor.opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private func personStatusUnit(
        partner: HomePartner,
        status: DailyStatus?,
        fallbackTone: StatusTone,
        fallbackText: String,
        isHighlighted: Bool
    ) -> some View {
        let tone = status?.tone ?? fallbackTone

        return VStack(spacing: 8) {
            avatar(
                initials: partner.initials,
                ringColor: AppTheme.Colors.statusTone(tone),
                isHighlighted: isHighlighted
            )

            Text(partner.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            statusChip(status: status, fallbackTone: fallbackTone, fallbackText: fallbackText)
        }
        .frame(width: 82)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color.white.opacity(isHighlighted ? 0.42 : 0.28))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func statusChip(
        status: DailyStatus?,
        fallbackTone: StatusTone,
        fallbackText: String
    ) -> some View {
        let tone = status?.tone ?? fallbackTone

        return HStack(spacing: 5) {
            Circle()
                .fill(AppTheme.Colors.statusTone(tone))
                .frame(width: 6, height: 6)

            Text(status?.mood ?? fallbackText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.Colors.deepAccent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 EEEE"
        return formatter
    }()
}
