import Foundation

public struct Supplement: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var brand: String?
    public var dose: String? // e.g. "5000 IU", "250 mg"
    public var category: String?
    public var timeOfDay: DateComponents? // e.g. 8:00
    public var timeContext: String? // e.g. "Avant le repas"
    public var frequency: Frequency
    // Nombre de prises par jour si > 1 (applicable au quotidien et à l'hebdomadaire)
    public var timesPerDay: Int? = nil
    // Jours de la semaine sélectionnés (1=Lun ... 7=Dim) pour hebdomadaire ou x fois/semaine
    public var daysOfWeek: [Int]? = nil
    public var durationNote: String?
    public var notes: String?
    public var active: Bool = true
    public var activationSpans: [ActivationSpan] = []
}

public struct SupplementIntake: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var supplementId: UUID
    public var date: Date
    public var taken: Bool
}
