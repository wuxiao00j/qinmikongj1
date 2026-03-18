import SwiftUI

struct LifeHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeroLabel(text: "两个人的日常", systemImage: "leaf")

            Text("把吃饭、安排和想一起去的地方，轻轻留在今天的节奏里。")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.subtitle)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}
