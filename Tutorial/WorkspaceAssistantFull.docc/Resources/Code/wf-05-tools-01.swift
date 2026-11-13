import FoundationModels

/// Builds the assistant's tool set over a toolbox and recorder.
enum WorkspaceTools {
    static func make(toolbox: WorkspaceToolbox, recorder: ToolActivityRecorder) -> [any Tool] {
        [
            FindTasksTool(toolbox: toolbox, recorder: recorder),
            AddTaskTool(toolbox: toolbox, recorder: recorder),
        ]
    }
}

/// Runs a toolbox operation on the main actor, reports its activity, and returns the message.
private func run(_ recorder: ToolActivityRecorder, _ operation: @MainActor () -> ToolResult) async -> String {
    await MainActor.run {
        let result = operation()
        recorder.record(result.activity)
        return result.message
    }
}

/// Looks up tasks by title words before acting.
struct FindTasksTool: Tool {
    let name = "findTasks"
    let description = "Looks up tasks by title. Returns titles, ids, category, priority and status. Use an empty query to list all open tasks."
    let toolbox: WorkspaceToolbox
    let recorder: ToolActivityRecorder

    @Generable
    struct Arguments {
        @Guide(description: "Words from the task title, or empty to list all open tasks")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await run(recorder) { toolbox.findTasks(query: arguments.query) }
    }
}

/// Creates a task.
struct AddTaskTool: Tool {
    let name = "addTask"
    let description = "Creates a new task."
    let toolbox: WorkspaceToolbox
    let recorder: ToolActivityRecorder

    @Generable
    struct Arguments {
        @Guide(description: "Short task title in title case, e.g. 'Code Review'")
        var title: String
        var category: CategoryArgument
        var priority: PriorityArgument
    }

    func call(arguments: Arguments) async throws -> String {
        await run(recorder) {
            toolbox.addTask(title: arguments.title, category: arguments.category.domain, priority: arguments.priority.domain)
        }
    }
}
