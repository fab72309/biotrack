import Foundation

enum SharedStore {
    enum LoadStatus {
        case loaded
        case fileMissing
        case recoveredFromReadError
        case recoveredFromDecodeError

        var recoveredFromCorruption: Bool {
            switch self {
            case .recoveredFromReadError, .recoveredFromDecodeError:
                return true
            case .loaded, .fileMissing:
                return false
            }
        }
    }

    static private(set) var lastLoadStatus: LoadStatus = .fileMissing
    static private(set) var lastRecoveredStoreBackupURL: URL?

    static func load() -> BioTrackSnapshot {
        let url = AppGroup.storeURL()
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            lastLoadStatus = .fileMissing
            lastRecoveredStoreBackupURL = nil
            var fresh = BioTrackSnapshot()
            MigrationService.migrate(&fresh)
            return fresh
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            lastLoadStatus = .recoveredFromReadError
            lastRecoveredStoreBackupURL = preserveCorruptedStoreIfPossible(at: url)
            print("SharedStore load error (read):", error, "backup:", lastRecoveredStoreBackupURL?.path ?? "none")
            var fresh = BioTrackSnapshot()
            MigrationService.migrate(&fresh)
            return fresh
        }

        guard var snapshot = try? JSONDecoder().decode(BioTrackSnapshot.self, from: data) else {
            lastLoadStatus = .recoveredFromDecodeError
            lastRecoveredStoreBackupURL = preserveCorruptedStoreIfPossible(at: url)
            print("SharedStore load error (decode). backup:", lastRecoveredStoreBackupURL?.path ?? "none")
            var fresh = BioTrackSnapshot()
            MigrationService.migrate(&fresh)
            return fresh
        }

        lastLoadStatus = .loaded
        lastRecoveredStoreBackupURL = nil
        let previousVersion = snapshot.schemaVersion
        MigrationService.migrate(&snapshot)
        if snapshot.schemaVersion != previousVersion {
            save(snapshot)
        }
        return snapshot
    }

    static func save(_ snapshot: BioTrackSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            let url = AppGroup.storeURL()
            try data.write(to: url, options: .atomic)
            AppGroup.excludeFromBackup(url)
        } catch {
            print("SharedStore save error:", error)
        }
    }

    static func mutate(_ mutateBlock: (inout BioTrackSnapshot) -> Void) {
        var snapshot = load()
        mutateBlock(&snapshot)
        save(snapshot)
    }

    private static func preserveCorruptedStoreIfPossible(at originalURL: URL) -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: originalURL.path) else { return nil }

        let ext = originalURL.pathExtension
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let timestamp = corruptionTimestamp()
        let suffix = String(UUID().uuidString.prefix(8))
        let backupFileName = ext.isEmpty
            ? "\(baseName).corrupt-\(timestamp)-\(suffix)"
            : "\(baseName).corrupt-\(timestamp)-\(suffix).\(ext)"
        let backupURL = originalURL.deletingLastPathComponent().appendingPathComponent(backupFileName)

        do {
            try fm.moveItem(at: originalURL, to: backupURL)
            AppGroup.excludeFromBackup(backupURL)
            return backupURL
        } catch {
            // Try copy as a fallback so the original file remains inspectable.
            do {
                try fm.copyItem(at: originalURL, to: backupURL)
                AppGroup.excludeFromBackup(backupURL)
                return backupURL
            } catch {
                print("SharedStore backup preserve error:", error)
                return nil
            }
        }
    }

    private static func corruptionTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
