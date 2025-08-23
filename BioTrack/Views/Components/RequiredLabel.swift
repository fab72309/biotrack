import SwiftUI

struct RequiredHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title) + Text(" *").foregroundColor(.red)
    }
}


