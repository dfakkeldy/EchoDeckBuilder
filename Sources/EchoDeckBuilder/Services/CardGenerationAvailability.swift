import Foundation

public struct CardGenerationAvailability: Equatable, Sendable {
    public let isAvailable: Bool
    public let message: String

    public static func available(_ message: String) -> CardGenerationAvailability {
        CardGenerationAvailability(isAvailable: true, message: message)
    }

    public static func unavailable(_ message: String) -> CardGenerationAvailability {
        CardGenerationAvailability(isAvailable: false, message: message)
    }
}

public enum CardGenerationError: LocalizedError, Sendable {
    case unavailable(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message), .failed(let message):
            return message
        }
    }
}
