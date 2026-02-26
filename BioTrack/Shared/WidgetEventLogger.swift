import Foundation

enum WidgetEventLogger {
    static func log(_ name: String, metadata: [String: String] = [:]) {
        let defaults = AppGroup.sharedDefaults()
        let prefix = "analytics.\(name)"
        defaults.set((defaults.integer(forKey: "\(prefix).count") + 1), forKey: "\(prefix).count")
        defaults.set(Date(), forKey: "\(prefix).lastDate")
        for (key, value) in metadata {
            defaults.set(value, forKey: "\(prefix).\(key)")
        }
        print("WidgetEvent:", name, metadata)
    }
}
