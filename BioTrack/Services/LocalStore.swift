import Foundation

final class LocalStore {
    static let shared = LocalStore()
    private init() {}

    typealias Snapshot = BioTrackSnapshot

    func load() -> Snapshot {
        SharedStore.load()
    }

    func save(_ snapshot: Snapshot) {
        SharedStore.save(snapshot)
    }
}
