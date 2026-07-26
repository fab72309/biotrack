import SwiftUI

struct SwipeableRow<Content: View>: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTap: (() -> Void)?
    let content: () -> Content

    @GestureState private var dragX: CGFloat = 0
    @State private var showLeading: Bool = false
    @State private var showTrailing: Bool = false
    @State private var bounceOffset: CGFloat = 0

    private let buttonSize: CGFloat = 52

    init(
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                ZStack {
                    // Leading (edit)
                    HStack {
                        Button(action: { onEdit(); close() }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("OnPrimary"))
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color("Primary"))
                                .clipShape(Circle())
                        }
                        .opacity(showLeading || dragX > 10 ? 1 : 0)
                        .allowsHitTesting(showLeading || dragX > 10)
                        .disabled(showTrailing)
                        Spacer()
                    }
                    .zIndex(showLeading ? 3 : 2)
                    // Trailing (delete)
                    HStack {
                        Spacer()
                        Button(role: .destructive, action: { close(); onDelete() }) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .opacity(showTrailing || dragX < -10 ? 1 : 0)
                        .allowsHitTesting(showTrailing || dragX < -10)
                        .disabled(showLeading)
                    }
                    .zIndex(showTrailing ? 3 : 2)

                    // Content stays visible
                    content()
                        .contentShape(Rectangle())
                        .offset(x: contentOffset)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gesture(drag)
                        .onTapGesture {
                            if showLeading || showTrailing {
                                close()
                            } else {
                                onTap?()
                            }
                        }
                        .zIndex(1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityHint(Text("Balayez à droite pour modifier, à gauche pour supprimer"))
                .accessibilityActions {
                    Button("Modifier", action: onEdit)
                    Button("Supprimer", action: onDelete)
                }
            } else {
                ZStack {
                    // Leading (edit)
                    HStack {
                        Button(action: { onEdit(); close() }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("OnPrimary"))
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color("Primary"))
                                .clipShape(Circle())
                        }
                        .opacity(showLeading || dragX > 10 ? 1 : 0)
                        .allowsHitTesting(showLeading || dragX > 10)
                        .disabled(showTrailing)
                        Spacer()
                    }
                    .zIndex(showLeading ? 3 : 2)
                    // Trailing (delete)
                    HStack {
                        Spacer()
                        Button(role: .destructive, action: { close(); onDelete() }) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .opacity(showTrailing || dragX < -10 ? 1 : 0)
                        .allowsHitTesting(showTrailing || dragX < -10)
                        .disabled(showLeading)
                    }
                    .zIndex(showTrailing ? 3 : 2)

                    // Content stays visible
                    content()
                        .contentShape(Rectangle())
                        .offset(x: contentOffset)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gesture(drag)
                        .onTapGesture {
                            if showLeading || showTrailing {
                                close()
                            } else {
                                onTap?()
                            }
                        }
                        .zIndex(1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityHint(Text("Balayez à droite pour modifier, à gauche pour supprimer"))
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragX) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    if value.translation.width > 24 { // swipe right → reveal edit only
                        showLeading = true; showTrailing = false; haptic()
                    } else if value.translation.width < -24 { // swipe left → reveal delete only
                        showLeading = false; showTrailing = true; haptic()
                    } else {
                        close()
                    }
                }
            }
    }

    private func close() {
        let directionOffset: CGFloat = showLeading ? -6 : (showTrailing ? 6 : 0)
        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
            bounceOffset = directionOffset
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8).delay(0.05)) {
            bounceOffset = 0
            showLeading = false; showTrailing = false
        }
    }

    private var contentOffset: CGFloat {
        let revealShift: CGFloat = (showLeading ? (buttonSize + 20) : 0) + (showTrailing ? -(buttonSize + 20) : 0)
        // during drag (no state chosen yet), preview a small shift to hint action
        let dragPreview: CGFloat = {
            if showLeading || showTrailing { return 0 }
            let clamped = max(min(dragX, buttonSize + 12), -(buttonSize + 12))
            return clamped * 0.3 // slightly larger preview
        }()
        return bounceOffset + revealShift + dragPreview
    }

    private func haptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

