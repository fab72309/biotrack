import SwiftUI

extension View {
    @ViewBuilder
    func withSheetDetentsIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}


