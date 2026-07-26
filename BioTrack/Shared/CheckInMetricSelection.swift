import Foundation

enum CheckInMetricSelection {
    static let storageKey = "checkInSelectedMetricIds"

    static func parse(_ raw: String) -> Set<UUID> {
        Set(parseOrdered(raw))
    }

    static func parseOrdered(_ raw: String) -> [UUID] {
        var seen: Set<UUID> = []
        var ordered: [UUID] = []

        for token in raw
            .split(separator: ",")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            guard let id = UUID(uuidString: token), !seen.contains(id) else { continue }
            seen.insert(id)
            ordered.append(id)
        }

        return ordered
    }

    static func encode(_ ids: [UUID]) -> String {
        var seen: Set<UUID> = []
        let uniqueOrdered = ids.filter {
            if seen.contains($0) { return false }
            seen.insert($0)
            return true
        }
        return uniqueOrdered
            .map(\.uuidString)
            .joined(separator: ",")
            .replacingOccurrences(of: " ", with: "")
    }

    static func encode(_ ids: Set<UUID>) -> String {
        encode(Array(ids).sorted { $0.uuidString < $1.uuidString })
    }

    static func sanitizeOrdered(_ ids: [UUID], availableIds: [UUID]) -> [UUID] {
        let available = Set(availableIds)
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for id in ids where available.contains(id) {
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(id)
        }
        return result
    }
}
