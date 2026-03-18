import SwiftUI

struct AnniversaryDetailView: View {
    let anniversary: AnniversaryHighlight

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(anniversary.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text(anniversary.dateText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.tint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("还有 \(anniversary.daysRemaining) 天")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text(anniversary.note)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }

                AppSectionCard(
                    title: "这一天的时间信息",
                    subtitle: "这里先集中查看当前纪念日的日期、倒计时和备注内容。",
                    symbol: "calendar.badge.clock"
                ) {
                    Text("如果今天是重要日子，会直接显示为今天；如果还没到，就继续按剩余天数提示，方便在首页快速确认。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.subtitle)
                        .lineSpacing(4)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("纪念日详情")
            .secondaryPageNavigationStyle()
        }
        .presentationDetents([.medium, .large])
    }
}
