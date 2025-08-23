import Foundation

final class ChecklistViewModel: ObservableObject {
    @Published var todayItems: [ChecklistItem] = []
    
    struct ChecklistItem: Identifiable {
        let id = UUID()
        let title: String
        var done: Bool
        let onToggle: (Bool) -> Void
    }
    
    func build(from state: AppState) {
        var items: [ChecklistItem] = []
        // Protocols due today (simplified: include all daily)
        for p in state.protocols {
            switch p.frequency {
            case .daily:
                items.append(ChecklistItem(title: p.name, done: false, onToggle: { _ in }))
            default:
                break
            }
        }
        // Supplements active today (simplified: include all active)
        for s in state.supplements where s.active {
            items.append(ChecklistItem(title: s.name, done: false, onToggle: { _ in }))
        }
        self.todayItems = items
    }
}
