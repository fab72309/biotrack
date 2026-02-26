#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

final class ProtocolLiveActivityService {
    static let shared = ProtocolLiveActivityService()
    private init() {}

    private let activeIdKey = "liveActivity.protocol.id"

    func start(protocolId: UUID, protocolName: String, durationMinutes: Int) {
        guard FeatureFlags.liveActivitiesEnabled else { return }
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let end = Date().addingTimeInterval(TimeInterval(max(1, durationMinutes) * 60))
        let attributes = ProtocolTimerAttributes(title: "Session protocole")
        let state = ProtocolTimerAttributes.ContentState(
            protocolId: protocolId.uuidString,
            protocolName: protocolName,
            endDate: end
        )
        do {
            for activity in Activity<ProtocolTimerAttributes>.activities {
                Task { await endActivity(activity) }
            }
            if #available(iOS 16.2, *) {
                _ = try Activity<ProtocolTimerAttributes>.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: end),
                    pushType: nil
                )
            } else {
                _ = try Activity<ProtocolTimerAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            UserDefaults.standard.set(protocolId.uuidString, forKey: activeIdKey)
        } catch {
            print("ProtocolLiveActivity start error:", error)
        }
        #endif
    }

    func stop() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        Task {
            for activity in Activity<ProtocolTimerAttributes>.activities {
                await endActivity(activity)
            }
            UserDefaults.standard.removeObject(forKey: activeIdKey)
        }
        #endif
    }

    func activeProtocolId() -> UUID? {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *),
           let active = Activity<ProtocolTimerAttributes>.activities.first {
            let rawId: String
            if #available(iOS 16.2, *) {
                rawId = active.content.state.protocolId
            } else {
                rawId = active.contentState.protocolId
            }
            if let uuid = UUID(uuidString: rawId) {
                UserDefaults.standard.set(rawId, forKey: activeIdKey)
                return uuid
            }
        }
        #endif
        guard let raw = UserDefaults.standard.string(forKey: activeIdKey) else { return nil }
        let id = UUID(uuidString: raw)
        if id == nil {
            UserDefaults.standard.removeObject(forKey: activeIdKey)
        }
        return id
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func endActivity(_ activity: Activity<ProtocolTimerAttributes>) async {
        if #available(iOS 16.2, *) {
            await activity.end(nil, dismissalPolicy: .immediate)
        } else {
            await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
        }
    }
    #endif
}
