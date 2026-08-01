import SwiftUI

extension View {
    @ViewBuilder
    func withSheetDetentsIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(BioTrackModalMetrics.cornerRadius)
                .presentationBackground(Color("Background"))
        } else if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

