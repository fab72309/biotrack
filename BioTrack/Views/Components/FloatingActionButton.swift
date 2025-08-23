import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(Color("Primary"))
                .clipShape(Circle())
        }
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        .accessibilityLabel(Text("Ajouter"))
        .accessibilityHint(Text("Ajoute un nouvel élément"))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        FloatingActionButton(action: {})
            .padding(.trailing, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}


