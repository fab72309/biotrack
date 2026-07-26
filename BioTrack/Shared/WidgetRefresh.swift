#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetRefresh {
    static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

