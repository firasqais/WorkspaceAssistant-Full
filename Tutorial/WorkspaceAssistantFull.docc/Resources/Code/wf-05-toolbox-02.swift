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

    // MARK: - Mutations

    /// Creates a task.
    public func addTask(title: String, category: TaskCategory, priority: TaskPriority) -> ToolResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let parameters: [ToolParameter] = [.text(trimmed), .category(category), .priority(priority)]
        do {
            let result = try executor.perform(.addTask(title: trimmed, category: category, priority: priority, origin: .assistant), actor: .assistant)
            let id = result.createdTaskID
            let priorityText = priority == .high ? "high" : "normal"
            return ToolResult(
                message: "Added '\(trimmed)' to \(category.rawValue) with \(priorityText) priority.",
                activity: ToolActivity(kind: .addTask, parameters: [.task(title: trimmed, id: id), .category(category), .priority(priority)], outcome: .success, taskIDs: id.map { [$0] } ?? [])
            )
        } catch WorkspaceError.emptyTitle {
            return ToolResult(
                message: "Not added: the title was empty. Ask the user what the task should be called.",
                activity: ToolActivity(kind: .addTask, parameters: parameters, outcome: .failure(.emptyTitle))
            )
        } catch {
            return failure(.addTask, parameters, error)
        }
    }

    // MARK: - Helpers

    private func failure(_ kind: ToolKind, _ parameters: [ToolParameter], _ error: any Error) -> ToolResult {
        Log.agent.error("Tool \(kind.rawValue, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        return ToolResult(
            message: "The change failed and nothing was modified (\(String(describing: error))).",
            activity: ToolActivity(kind: kind, parameters: parameters, outcome: .failure(.rejected(String(describing: error))))
        )
    }

    private func openTasksSummary() -> String {
        let open = executor.tasks.filter { !$0.isDone }.map { "'\($0.title)'" }
        return open.isEmpty ? "There are no open tasks." : "Open tasks: \(open.joined(separator: ", "))."
    }
}
