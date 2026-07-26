import Foundation

enum FeatureFlags {
    private static let defaults = AppGroup.sharedDefaults()

    static var checkInsEnabled: Bool { defaults.object(forKey: "feature.checkins") as? Bool ?? true }
    static var experimentsEnabled: Bool { defaults.object(forKey: "feature.experiments") as? Bool ?? true }
    static var liveActivitiesEnabled: Bool { defaults.object(forKey: "feature.liveActivities") as? Bool ?? true }
    static var routinesEnabled: Bool { defaults.object(forKey: "feature.routines") as? Bool ?? true }
    static var recommendationsEnabled: Bool { defaults.object(forKey: "feature.recommendations") as? Bool ?? true }
}
