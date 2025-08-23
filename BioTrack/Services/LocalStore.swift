import Foundation
// Ensure Reminder type visible
// Reminder model declared in BioTrack/Models/Reminder.swift within same module
// Ensure models visible here
// no extra imports needed

final class LocalStore {
    static let shared = LocalStore()
    private init() {}
    
    private var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("biotrack.json")
    }
    
    struct Snapshot: Codable {
        var protocols: [ProtocolItem] = []
        var protocolCompletions: [ProtocolCompletion] = []
        var supplements: [Supplement] = []
        var supplementIntakes: [SupplementIntake] = []
        var metrics: [Metric] = []
        var metricEntries: [MetricEntry] = []
        var reminders: [Reminder] = []
    }
    
    func load() -> Snapshot {
        guard let data = try? Data(contentsOf: url) else { return Snapshot() }
        let snap = (try? JSONDecoder().decode(Snapshot.self, from: data)) ?? Snapshot()
        return snap
    }
    
    func save(_ snapshot: Snapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            print("LocalStore save error:", error)
        }
    }
}
