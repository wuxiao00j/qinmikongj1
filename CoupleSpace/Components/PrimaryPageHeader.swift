import SwiftUI

struct PrimaryPageHeader: View {
    let title: String
    let subtitle: String?
    let labelText: String?
    let labelSystemImage: String?

    init(
        title: String,
        subtitle: String? = nil,
        labelText: String? = nil,
        labelSystemImage: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.labelText = labelText
        self.labelSystemImage = labelSystemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let labelText, let labelSystemImage {
                PageHeroLabel(text: labelText, systemImage: labelSystemImage)
            }

            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.title)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.subtitle)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}
