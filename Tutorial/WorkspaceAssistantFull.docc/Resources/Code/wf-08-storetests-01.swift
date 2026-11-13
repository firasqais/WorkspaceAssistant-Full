import Foundation
import Testing
@testable import WorkspaceAssistant

@MainActor
@Suite("WorkspaceStore commands and undo")
struct WorkspaceStoreTests {
    let fixture = StoreFixture()
    var store: WorkspaceStore { fixture.store }
    var network: TaskItem { fixture.task("Refactor Network Layer")! }

    @Test func seedsSampleTasksOnFirstLaunchOnly() throws {
        #expect(store.tasks.map(\.title) == SampleData.tasks().map(\.title))
        #expect(fixture.preferences.hasSeededSampleTasks)

        try fixture.perform(.deleteTasks(ids: store.tasks.map(\.id)))
        let relaunched = WorkspaceStore(repository: fixture.repository, preferencesStore: fixture.preferences)
        #expect(relaunched.tasks.isEmpty)
    }

    @Test func addTaskInsertsAtTopAndUndoRemovesIt() throws {
        let result = try fixture.perform(.addTask(title: "  Code review \n", category: .development, priority: .high, origin: .assistant))
        let created = try #require(result.createdTaskID.flatMap(store.task(id:)))
        #expect(created.title == "Code review")
        #expect(created.priority == .high)
        #expect(created.origin == .assistant)
        #expect(store.tasks.first?.id == created.id)
        #expect(try fixture.persisted().contains { $0.id == created.id })

        fixture.undo()
        #expect(store.task(id: created.id) == nil)
        #expect(try !fixture.persisted().contains { $0.id == created.id })

        fixture.redo()
        #expect(store.task(id: created.id)?.title == "Code review")
    }

    @Test func addTaskRejectsBlankTitle() {
        #expect(throws: WorkspaceError.emptyTitle) {
            try fixture.perform(.addTask(title: " \n ", category: .design, priority: .normal, origin: .user))
        }
    }
}
