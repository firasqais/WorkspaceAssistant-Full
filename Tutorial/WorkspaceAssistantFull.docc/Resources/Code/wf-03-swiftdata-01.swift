import Foundation
import SwiftData

/// A `TaskRepository` backed by SwiftData.
@MainActor
public final class SwiftDataTaskRepository: TaskRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Creates a repository. Pass `inMemory: true` for tests.
    public init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: TaskRecord.self, configurations: configuration)
    }

    public func fetchAll() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.sortIndex)])).map(\.taskItem)
    }
}
