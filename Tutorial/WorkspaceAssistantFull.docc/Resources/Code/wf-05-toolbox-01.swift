import Foundation
import os

/// The tools' shared logic: resolve tasks, issue `WorkspaceCommand`s as `.assistant`, and report
/// truthfully what happened — including "no match", "ambiguous" and "already done".
///
/// Used by the Foundation Models tool adapters and by `ScriptedEngine`, so both paths behave identically.
@MainActor
public final class WorkspaceToolbox: Sendable {
    private let executor: any WorkspaceCommandExecutor

    public init(executor: any WorkspaceCommandExecutor) {
        self.executor = executor
    }

    // MARK: - Lookup

    /// Lists tasks matching `query` (or all open tasks for an empty query) with ids and state.
    public func findTasks(query: String) -> ToolResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches: [TaskItem]
        if trimmed.isEmpty {
            matches = executor.tasks.filter { !$0.isDone }
        } else {
            switch executor.resolveTasks(matching: trimmed) {
            case .none: matches = []
            case let .unique(task): matches = [task]
            case let .ambiguous(tasks): matches = tasks
            }
        }
        guard !matches.isEmpty else {
            return ToolResult(
                message: "No task matches '\(trimmed)'. \(openTasksSummary())",
                activity: ToolActivity(kind: .findTasks, parameters: [.query(trimmed)], outcome: .failure(.noMatch(query: trimmed)))
            )
        }
        let lines = matches.map { task in
            "- '\(task.title)' (id: \(task.id.uuidString), category: \(task.category.rawValue), priority: \(task.priority.rawValue), status: \(task.status.rawValue), steps: \(task.completedStepCount)/\(task.steps.count))"
        }
        return ToolResult(
            message: "Found \(matches.count) task(s):\n" + lines.joined(separator: "\n"),
            activity: ToolActivity(kind: .findTasks, parameters: [.query(trimmed)], outcome: .success, taskIDs: matches.map(\.id))
        )
    }

    // MARK: - Helpers

    private func openTasksSummary() -> String {
        let open = executor.tasks.filter { !$0.isDone }.map { "'\($0.title)'" }
        return open.isEmpty ? "There are no open tasks." : "Open tasks: \(open.joined(separator: ", "))."
    }
}
