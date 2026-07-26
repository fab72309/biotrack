import Foundation

enum LocalAnalyticsService {
    static func track(_ name: String, metadata: [String: String] = [:]) {
        let defaults = AppGroup.sharedDefaults()
        let keyPrefix = "analytics.\(name)"
        defaults.set(defaults.integer(forKey: "\(keyPrefix).count") + 1, forKey: "\(keyPrefix).count")
        defaults.set(Date(), forKey: "\(keyPrefix).lastDate")
        for (key, value) in metadata {
            defaults.set(value, forKey: "\(keyPrefix).\(key)")
        }
    }

    static func exportDebugSummary() -> String {
        let defaults = AppGroup.sharedDefaults()
        let keys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("analytics.") }
            .sorted()
        var lines: [String] = ["analytics_debug_export"]
        lines.append(contentsOf: keys.map { "\($0)=\(defaults.object(forKey: $0) ?? "nil")" })
        return lines.joined(separator: "\n")
    }
}
