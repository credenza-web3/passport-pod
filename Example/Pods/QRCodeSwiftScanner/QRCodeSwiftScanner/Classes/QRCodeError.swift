

import Foundation

public enum QRCodeError: Error {
    case inputFailed
    case outoutFailed
    case emptyResult
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
}

extension QRCodeError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .inputFailed:
            return "Failed to add input."
        case .outoutFailed:
            return "Failed to add output."
        case .emptyResult:
            return "Empty string found."
        case .cameraPermissionDenied:
            return "Camera Permission Denied"
        case .photoLibraryPermissionDenied:
            return "Photo Library Permission Denied"
        }
    }
}

extension QRCodeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .inputFailed:
            return NSLocalizedString(
                "Failed to add input.",
                comment: "Failed to add input."
            )
        case .outoutFailed:
            return NSLocalizedString(
                "Failed to add output.",
                comment: "Failed to add output."
            )
        case .emptyResult:
            return NSLocalizedString(
                "Empty string found.",
                comment: "Empty string found."
            )
        case .cameraPermissionDenied:
            return NSLocalizedString(
                "PermissionDenied",
                comment: "Camera Permission Denied")
        case .photoLibraryPermissionDenied:
            return NSLocalizedString(
                "PermissionDenied",
                comment: "Photo Library Permission Denied")
        }
    }
}
