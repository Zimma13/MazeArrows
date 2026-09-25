import Foundation
import Observation

struct LevelMetadata: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var index: Int
    var modified: Date

    var displayTitle: String {
        name.isEmpty ? "Уровень \(index)" : name
    }
}

@Observable
@MainActor
final class LevelStore {
    var levels: [LevelMetadata] = []

    private var storeDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Levels", isDirectory: true)
    }

    init() { reload() }

    // MARK: - Save

    func save(_ vm: EditorViewModel) {
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let dict = vm.toStorageDict()
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
            try? data.write(to: fileURL(id: vm.id))
        }
        let meta = LevelMetadata(id: vm.id, name: vm.name, index: vm.index, modified: Date())
        if let i = levels.firstIndex(where: { $0.id == vm.id }) {
            levels[i] = meta
        } else {
            levels.insert(meta, at: 0)
        }
    }

    // MARK: - Load

    func load(id: String) -> EditorViewModel? {
        guard let data = try? Data(contentsOf: fileURL(id: id)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return EditorViewModel.from(dict: dict)
    }

    // MARK: - Delete

    func delete(ids: IndexSet) {
        let toDelete = ids.map { levels[$0] }
        toDelete.forEach { meta in
            try? FileManager.default.removeItem(at: fileURL(id: meta.id))
        }
        levels.remove(atOffsets: ids)
    }

    // MARK: - Private

    private func fileURL(id: String) -> URL {
        storeDir.appendingPathComponent("\(id).json")
    }

    private func reload() {
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: storeDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        )) ?? []

        levels = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> LevelMetadata? in
                guard let data = try? Data(contentsOf: url),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id   = dict["localId"] as? String
                else { return nil }
                let name     = dict["name"]  as? String ?? ""
                let index    = dict["index"] as? Int    ?? 1
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? Date.distantPast
                return LevelMetadata(id: id, name: name, index: index, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }
}
