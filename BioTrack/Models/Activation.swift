import Foundation

public struct ActivationSpan: Codable, Equatable {
    public var start: Date
    public var end: Date? // nil = en cours
}

public protocol Activable {
    var active: Bool { get set }
    var activationSpans: [ActivationSpan] { get set }
}

public extension Activable {
    func isActive(on date: Date) -> Bool {
        if activationSpans.isEmpty {
            return active
        }
        return activationSpans.contains { span in
            if let end = span.end {
                return span.start <= date && date < end
            } else {
                return span.start <= date
            }
        }
    }
}

// Conformités par défaut pour nos types du domaine
extension Supplement: Activable {}
extension ProtocolItem: Activable {}


