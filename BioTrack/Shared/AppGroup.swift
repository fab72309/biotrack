import Foundation

enum AppGroup {
    static let identifier = "group.com.fabienlopes.biotrack"
    static let storeFileName = "biotrack.json"

    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    static func sharedDefaults() -> UserDefaults {
        guard isAvailable else { return .standard }
        return UserDefaults(suiteName: identifier) ?? .standard
    }

    static func storeURL() -> URL {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return containerURL.appendingPathComponent(storeFileName)
        }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(storeFileName)
    }

    static func excludeFromBackup(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        } catch {
            print("AppGroup excludeFromBackup error:", error)
        }
    }
}
