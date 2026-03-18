import SwiftUI

private struct SecondaryPageNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar(.visible, for: .navigationBar)
            .toolbarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.homeBackgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppTheme.Colors.tint)
    }
}

extension View {
    func secondaryPageNavigationStyle() -> some View {
        modifier(SecondaryPageNavigationStyle())
    }
}
