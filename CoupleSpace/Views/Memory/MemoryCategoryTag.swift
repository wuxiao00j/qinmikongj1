import SwiftUI

struct MemoryCategoryTag: View {
    let category: MemoryCategory

    var body: some View {
        PageMetaPill(text: category.rawValue, systemImage: category.symbol)
    }
}
