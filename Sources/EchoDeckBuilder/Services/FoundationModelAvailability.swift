import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum FoundationModelAvailability {
    public static func current() -> CardGenerationAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return currentOnSupportedOS()
        } else {
            return .unavailable("Foundation Models requires macOS 26+")
        }
        #else
        return .unavailable("Foundation Models is not available in this Xcode SDK")
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func currentOnSupportedOS() -> CardGenerationAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            guard model.supportsLocale() else {
                return .unavailable("Foundation Models does not support the current language")
            }
            return .available("Foundation Models ready")
        case .unavailable(.deviceNotEligible):
            return .unavailable("Foundation Models requires an Apple Intelligence-capable Mac")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in System Settings to use Foundation Models")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence is still preparing the language model")
        @unknown default:
            return .unavailable("Foundation Models is unavailable")
        }
    }
    #endif
}
