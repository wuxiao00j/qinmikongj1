import SwiftUI

struct MessageDetailSheetView: View {
    let message: MessageHighlight

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近留言")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.title)

                    Text("来自 \(message.fromName) · \(message.timeText)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.tint)
                }

                Text("“\(message.content)”")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.title)
                    .lineSpacing(6)

                Text("只是很轻的一句话，也能让今天变得更柔软一点。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("留言详情")
            .secondaryPageNavigationStyle()
        }
        .presentationDetents([.medium])
    }
}
