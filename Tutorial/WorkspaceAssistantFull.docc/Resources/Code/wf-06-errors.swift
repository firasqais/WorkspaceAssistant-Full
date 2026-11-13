import Foundation
import FoundationModels

/// Maps Foundation Models errors (iOS 26 `GenerationError` and iOS 27 `LanguageModelError`) to `AssistantError`.
enum AssistantErrorMapping {
    static func map(_ error: any Error) -> AssistantError {
        if let mapped = error as? AssistantError { return mapped }
        if #available(iOS 27.0, *), let mapped = mapModern(error) { return mapped }
        if let generation = error as? LanguageModelSession.GenerationError { return map(generation) }
        return .other(String(describing: error))
    }

    /// iOS 26 error type (deprecated in iOS 27 but still the type thrown on iOS 26).
    static func map(_ error: LanguageModelSession.GenerationError) -> AssistantError {
        switch error {
        case .exceededContextWindowSize: .contextWindowExceeded
        case .assetsUnavailable: .assetsUnavailable
        case .guardrailViolation: .guardrailViolation
        case .unsupportedLanguageOrLocale: .unsupportedLanguage
        case .rateLimited: .rateLimited
        case .concurrentRequests: .busy
        case .refusal: .refusal
        case .unsupportedGuide, .decodingFailure: .other(String(describing: error))
        @unknown default: .other(String(describing: error))
        }
    }

    /// Reflective mapping for iOS 27 error types when running on newer OS versions.
    /// Uses type reflection so the package compiles against the current iOS 26 SDK without missing-type errors.
    private static func mapModern(_ error: any Error) -> AssistantError? {
        let typeName = String(reflecting: type(of: error))
        let desc = String(describing: error)

        if typeName.contains("LanguageModelError") {
            if desc.contains("contextSizeExceeded") || desc.contains("exceededContextWindowSize") {
                return .contextWindowExceeded
            }
            if desc.contains("rateLimited") { return .rateLimited }
            if desc.contains("guardrailViolation") { return .guardrailViolation }
            if desc.contains("refusal") { return .refusal }
            if desc.contains("unsupportedLanguage") { return .unsupportedLanguage }
            if desc.contains("timeout") { return .timeout }
            return .other(desc)
        }

        if typeName.contains("LanguageModelSession") && typeName.contains("Error") {
            if desc.contains("concurrentRequests") { return .busy }
            return .other(desc)
        }

        if typeName.contains("SystemLanguageModel") && typeName.contains("Error") {
            if desc.contains("assetsUnavailable") { return .assetsUnavailable }
            return .other(desc)
        }

        return nil
    }

    /// Maps the system model's availability.
    static func map(_ availability: SystemLanguageModel.Availability) -> AssistantAvailability {
        switch availability {
        case .available: .available
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible: .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled: .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady: .unavailable(.modelNotReady)
            @unknown default: .unavailable(.modelNotReady)
            }
        }
    }
}
