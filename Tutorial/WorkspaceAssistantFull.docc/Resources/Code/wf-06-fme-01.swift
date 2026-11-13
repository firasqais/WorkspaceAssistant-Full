import Foundation
import FoundationModels
import os

/// The Apple Intelligence assistant: one long-lived `LanguageModelSession` with the workspace tools,
/// streaming replies and reporting each tool call as it happens.
@MainActor
public final class FoundationModelsEngine {
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

    public func reset() async {
        session = Self.makeSession(model: model, tools: tools, summary: nil)
    }

    public func prewarm() async {
        guard availability.isAvailable else { return }
        session.prewarm()
    }

    private static func makeSession(model: SystemLanguageModel, tools: [any Tool], summary: String?) -> LanguageModelSession {
        var instructions = AssistantInstructions.text
        if let summary {
            instructions += "\nEarlier in this conversation (summary):\n\(summary)"
        }
        return LanguageModelSession(model: model, tools: tools, instructions: instructions)
    }
}
