import Foundation
import FoundationModels
import os

/// The Apple Intelligence assistant: one long-lived `LanguageModelSession` with the workspace tools,
/// streaming replies and reporting each tool call as it happens.
@MainActor
public final class FoundationModelsEngine: AssistantEngine {
    private let model: SystemLanguageModel
    private let tools: [any Tool]
    private let recorder: ToolActivityRecorder
    private var session: LanguageModelSession

    public init(executor: any WorkspaceCommandExecutor, model: SystemLanguageModel = .default) {
        self.model = model
        recorder = ToolActivityRecorder()
        tools = WorkspaceTools.make(toolbox: WorkspaceToolbox(executor: executor), recorder: recorder)
        session = Self.makeSession(model: model, tools: tools, summary: nil)
    }

    public var availability: AssistantAvailability {
        let mapped = AssistantErrorMapping.map(model.availability)
        if mapped.isAvailable, !model.supportsLocale() { return .unavailable(.unsupportedLanguage) }
        return mapped
    }

    public var simulationReason: AssistantUnavailableReason? { nil }

    public var isResponding: Bool { session.isResponding }

    public func send(_ prompt: String) -> AsyncThrowingStream<AssistantEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                await self.respond(to: prompt, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func reset() async {
        session = Self.makeSession(model: model, tools: tools, summary: nil)
    }

    public func prewarm() async {
        guard availability.isAvailable else { return }
        session.prewarm()
    }

    // MARK: - Responding

    private func respond(to prompt: String, continuation: AsyncThrowingStream<AssistantEvent, any Error>.Continuation) async {
        if case let .unavailable(reason) = availability {
            continuation.finish(throwing: AssistantError.unavailable(reason))
            return
        }
        guard !session.isResponding else {
            continuation.finish(throwing: AssistantError.busy)
            return
        }
        recorder.onActivity = { continuation.yield(.toolCalled($0)) }
        defer { recorder.onActivity = nil }

        do {
            var reply = ""
            for try await snapshot in session.streamResponse(to: prompt) {
                try Task.checkCancellation()
                reply = snapshot.content
                continuation.yield(.partialText(reply))
            }
            continuation.yield(.completed(reply))
            continuation.finish()
        } catch is CancellationError {
            continuation.finish(throwing: CancellationError())
        } catch {
            let mapped = AssistantErrorMapping.map(error)
            Log.agent.error("Generation failed: \(String(describing: error), privacy: .public)")
            continuation.finish(throwing: mapped)
        }
    }

    private static func makeSession(model: SystemLanguageModel, tools: [any Tool], summary: String?) -> LanguageModelSession {
        var instructions = AssistantInstructions.text
        if let summary {
            instructions += "\nEarlier in this conversation (summary):\n\(summary)"
        }
        return LanguageModelSession(model: model, tools: tools, instructions: instructions)
    }
}
