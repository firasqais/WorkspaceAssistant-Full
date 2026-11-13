import Foundation
import Observation
import os

/// The single source of truth the UI observes. Every mutation goes through `perform(_:actor:)`.
@MainActor
@Observable
public final class WorkspaceStore {
    /// All tasks, sorted by `sortIndex`.
    public private(set) var tasks: [TaskItem] = []
    /// Presentation preferences.
    public private(set) var preferences: WorkspacePreferences

    @ObservationIgnored private let repository: any TaskRepository
    @ObservationIgnored private let preferencesStore: any PreferencesStore

    /// Loads tasks and preferences, seeding the sample tasks on first launch only.
    public init(
        repository: any TaskRepository,
        preferencesStore: any PreferencesStore,
        seed: @autoclosure () -> [TaskItem] = SampleData.tasks()
    ) {
        self.repository = repository
        self.preferencesStore = preferencesStore
        preferences = preferencesStore.load()

        var loaded: [TaskItem] = []
        do {
            loaded = try repository.fetchAll()
        } catch {
            Log.persistence.error("Failed to load tasks: \(error.localizedDescription, privacy: .public)")
        }
        if loaded.isEmpty && !preferencesStore.hasSeededSampleTasks {
            loaded = seed()
            do {
                try repository.upsert(loaded)
            } catch {
                Log.persistence.error("Failed to seed tasks: \(error.localizedDescription, privacy: .public)")
            }
        }
        preferencesStore.hasSeededSampleTasks = true
        tasks = loaded.sorted(by: Self.ordering)
    }

    /// Returns the task with the given id, if it exists.
    public func task(id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    public func resolveTasks(matching query: String) -> TaskMatch {
        TaskMatcher.match(query, in: tasks)
    }

    // MARK: - Ordering

    private static func ordering(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        lhs.sortIndex == rhs.sortIndex ? lhs.createdAt > rhs.createdAt : lhs.sortIndex < rhs.sortIndex
    }

    /// A sort index that places an item at `index` within `ordered` (which must be sorted).
    static func sortIndex(at index: Int, in ordered: [TaskItem]) -> Double {
        switch (ordered.indices.contains(index - 1) ? ordered[index - 1] : nil, ordered.indices.contains(index) ? ordered[index] : nil) {
        case (nil, nil): 0
        case let (nil, next?): next.sortIndex - 1
        case let (previous?, nil): previous.sortIndex + 1
        case let (previous?, next?): (previous.sortIndex + next.sortIndex) / 2
        }
    }
}
