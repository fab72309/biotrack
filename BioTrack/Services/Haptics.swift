import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum Haptics {
    static func success() {
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }
    static func warning() {
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }
    static func error() {
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
        #endif
    }
    static func lightImpact() {
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }
}


