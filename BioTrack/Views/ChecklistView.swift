import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var vm = ChecklistViewModel()
    
    var body: some View {
        NavigationView {
            List {
                if vm.todayItems.isEmpty {
                    EmptyStateView(text: NSLocalizedString("empty.state", comment: ""))
                } else {
                    ForEach(vm.todayItems) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { item.done },
                                set: { newVal in item.onToggle(newVal) }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle(Text(NSLocalizedString("tab.checklist", comment: "")))
            .onAppear { vm.build(from: state) }
        }
    }
}

#Preview {
    ChecklistView().environmentObject(AppState())
}
