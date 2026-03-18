import SwiftUI

struct SettingsSectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let items: [SettingsItem]
    let onSelect: (SettingsItem) -> Void

    var body: some View {
        AppSectionCard(
            title: title,
            subtitle: subtitle,
            symbol: symbol
        ) {
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]

                    Button {
                        onSelect(item)
                    } label: {
                        SettingsItemRow(item: item)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}
