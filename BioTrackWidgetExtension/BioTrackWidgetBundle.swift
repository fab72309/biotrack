import SwiftUI
import WidgetKit

@main
struct BioTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        BioTrackWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            ProtocolLiveActivityWidget()
        }
    }
}
