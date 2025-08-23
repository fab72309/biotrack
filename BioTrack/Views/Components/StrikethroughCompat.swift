import SwiftUI

struct StrikethroughCompat: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if active {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: geo.size.width, height: 1)
                            .opacity(0.8)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}


