import SwiftUI

struct MemoryAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.Colors.tint)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("新增记忆")
    }
}
