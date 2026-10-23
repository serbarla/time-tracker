import Combine
import Foundation

/// Loads, mutates, and persists checks to a JSON file; publishes changes for the UI.
@MainActor
public final class CheckStore: ObservableObject {
    @Published public private(set) var checks: [Check] = []

    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL = CheckStore.defaultFileURL()) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        load()
    }

    public static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TimeTracker", isDirectory: true)
        return dir.appendingPathComponent("checks.json")
    }

    public func add(_ check: Check) {
        checks.append(check)
        save()
    }

    public func update(_ check: Check) {
        guard let i = checks.firstIndex(where: { $0.id == check.id }) else { return }
        checks[i] = check
        save()
    }

    public func remove(id: UUID) {
        checks.removeAll { $0.id == id }
        save()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let sorted = source.sorted()
        let moving = sorted.map { checks[$0] }
        for idx in sorted.reversed() {
            checks.remove(at: idx)
        }
        var insertion = destination
        for idx in sorted where idx < destination {
            insertion -= 1
        }
        checks.insert(contentsOf: moving, at: min(insertion, checks.count))
        save()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(ChecksFile.self, from: data) else {
            checks = []
            return
        }
        checks = decoded.checks
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(ChecksFile(version: ChecksFile.currentVersion, checks: checks))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal for a menubar utility.
            print("CheckStore save failed: \(error)")
        }
    }
}
