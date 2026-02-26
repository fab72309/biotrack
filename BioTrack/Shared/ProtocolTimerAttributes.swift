#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct ProtocolTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var protocolId: String
        var protocolName: String
        var endDate: Date
    }

    var title: String
}
#endif
