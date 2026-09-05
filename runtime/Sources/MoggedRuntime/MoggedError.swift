import Foundation

public enum MoggedError: Error, Equatable {
    case profilesNotFound
    case invalidProfile(String, String)
    case gameNotFound(String)
    case executableNotFound(String)
    case runtimeUnavailable
    case alreadyRunning(String)
    case notRunning(String)
    case launchFailed
    case alreadyInstalling(String)
    case installFailed(String)
    case installNeedsAccount

    /// Shown in the app. Never names a toolkit.
    public var userMessage: String {
        switch self {
        case .profilesNotFound, .invalidProfile:
            return "Mogged couldn't load its game list."
        case .gameNotFound:
            return "This game isn't installed. Install it, or Locate the folder."
        case .executableNotFound:
            return "Mogged found the folder, but not the game."
        case .runtimeUnavailable:
            return "Mogged can't start this game on this Mac yet."
        case .alreadyRunning:
            return "This game is already running."
        case .notRunning:
            return "That game isn't running."
        case .launchFailed:
            return "Couldn't start the game."
        case .alreadyInstalling:
            return "This game is already installing."
        case .installFailed(let detail):
            return detail.isEmpty ? "Couldn't install this game." : detail
        case .installNeedsAccount:
            return "Enter your Steam account to install."
        }
    }

    public var logDescription: String {
        switch self {
        case .profilesNotFound:
            return "profiles directory not found"
        case .invalidProfile(let file, let reason):
            return "invalid profile \(file): \(reason)"
        case .gameNotFound(let id):
            return "no install for \(id)"
        case .executableNotFound(let name):
            return "exe not found: \(name)"
        case .runtimeUnavailable:
            return "no execution backend configured or detected"
        case .alreadyRunning(let id):
            return "already running \(id)"
        case .notRunning(let id):
            return "not running \(id)"
        case .launchFailed:
            return "backend spawn failed"
        case .alreadyInstalling(let id):
            return "already installing \(id)"
        case .installFailed(let detail):
            return "install failed: \(detail)"
        case .installNeedsAccount:
            return "steam account required"
        }
    }
}
