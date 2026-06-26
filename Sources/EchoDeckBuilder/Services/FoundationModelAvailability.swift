import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum FoundationModelAvailability {
    static let unsupportedOSMessage = "Foundation Models requires macOS 26+"
    static let unsupportedSDKMessage = "Foundation Models is not available in this Xcode SDK"
    static let readyMessage = "Foundation Models ready"
    static let unsupportedLanguageMessage = "Foundation Models does not support the current language"
    static let deviceNotEligibleMessage = "Foundation Models requires an Apple Intelligence-capable Mac"
    static let appleIntelligenceDisabledMessage = "Turn on Apple Intelligence in System Settings to use Foundation Models"
    static let modelAssetsNotReadyMessage = "Apple Intelligence language model assets are downloading or not ready"
    static let modelAssetsUnavailableMessage = "Apple Intelligence language model assets are unavailable"
    static let unavailableMessage = "Foundation Models is unavailable"

    public static func current() -> CardGenerationAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return currentOnSupportedOS()
        } else {
            return .unavailable(unsupportedOSMessage)
        }
        #else
        return .unavailable(unsupportedSDKMessage)
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func currentOnSupportedOS() -> CardGenerationAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            guard model.supportsLocale() else {
                return .unavailable(unsupportedLanguageMessage)
            }
            return .available(readyMessage)
        case .unavailable(.deviceNotEligible):
            return .unavailable(deviceNotEligibleMessage)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(appleIntelligenceDisabledMessage)
        case .unavailable(.modelNotReady):
            return .unavailable(modelAssetsNotReadyMessage)
        @unknown default:
            return .unavailable(unavailableMessage)
        }
    }
    #endif
}
