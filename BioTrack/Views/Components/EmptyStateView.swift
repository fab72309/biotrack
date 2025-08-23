import SwiftUI

struct EmptyStateView: View {
    let text: String
    let systemImageName: String
    
    init(text: String, systemImageName: String = "leaf") {
        self.text = text
        self.systemImageName = systemImageName
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImageName)
                .font(.title)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview {
    EmptyStateView(text: "Empty")
}
