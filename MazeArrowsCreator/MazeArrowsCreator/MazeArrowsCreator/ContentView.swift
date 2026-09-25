import SwiftUI

struct ContentView: View {
    @State private var store = LevelStore()
    @State private var activeVM: EditorViewModel? = nil
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            levelList
                .navigationDestination(for: String.self) { vmId in
                    if let vm = activeVM, vm.id == vmId {
                        EditorView(vm: vm, store: store)
                    }
                }
        }
    }

    // MARK: Level list

    private var levelList: some View {
        List {
            if store.levels.isEmpty {
                ContentUnavailableView(
                    "Нет уровней",
                    systemImage: "square.grid.3x3",
                    description: Text("Нажмите «+» чтобы создать первый уровень")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.levels) { meta in
                    Button { openLevel(id: meta.id) } label: {
                        LevelRow(meta: meta)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { store.delete(ids: $0) }
            }
        }
        .navigationTitle("Мои уровни")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newLevel() } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
    }

    // MARK: Navigation

    private func openLevel(id: String) {
        guard let vm = store.load(id: id) else { return }
        activeVM = vm
        // Delay navigation by one run-loop tick so activeVM is committed
        // before navigationDestination evaluates the destination view.
        Task { @MainActor in path.append(id) }
    }

    private func newLevel() {
        let vm = EditorViewModel()
        vm.index = (store.levels.map(\.index).max() ?? 0) + 1
        activeVM = vm
        Task { @MainActor in path.append(vm.id) }
    }
}

// MARK: - Level row

private struct LevelRow: View {
    let meta: LevelMetadata

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text("\(meta.index)")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meta.displayTitle)
                    .font(.body)
                Text(meta.modified, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
