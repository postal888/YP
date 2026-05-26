import Foundation

@MainActor
public final class YouTubePlayerController: ObservableObject {
    @Published public private(set) var state: YouTubePlayerState = .idle
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0

    public var onEvent: ((YouTubePlayerEvent) -> Void)?

    fileprivate var pendingCommand: YouTubePlayerCommand?
    fileprivate var isWebViewReady = false

    public init() {}

    public func play() {
        send(.play)
    }

    public func pause() {
        send(.pause)
    }

    public func seek(to seconds: Double) {
        send(.seek(to: seconds))
    }

    public func load(videoID: String, startTime: Double = 0) {
        isWebViewReady = false
        state = .loading
        currentTime = 0
        duration = 0
        send(.load(videoID: videoID, startTime: startTime))
    }

    fileprivate func send(_ command: YouTubePlayerCommand) {
        pendingCommand = command
    }

    func consumePendingCommand() -> YouTubePlayerCommand? {
        defer { pendingCommand = nil }
        return pendingCommand
    }

    func handleBridgeMessage(_ message: BridgeMessage) {
        switch message {
        case .ready:
            isWebViewReady = true
            updateState(.ready)
            onEvent?(.ready)

        case .state(let rawValue):
            let mapped = mapPlayerState(rawValue)
            updateState(mapped)
            onEvent?(.stateChanged(mapped))

        case .progress(let current, let total):
            currentTime = current
            duration = total
            onEvent?(.progress(currentTime: current, duration: total))

        case .ended:
            updateState(.ended)
            onEvent?(.ended)

        case .error(let text):
            updateState(.error(text))
            onEvent?(.error(text))
        }
    }

    private func updateState(_ newState: YouTubePlayerState) {
        state = newState
    }

    private func mapPlayerState(_ rawValue: Int) -> YouTubePlayerState {
        switch rawValue {
        case -1: return .idle
        case 0: return .ended
        case 1: return .playing
        case 2: return .paused
        case 3: return .buffering
        case 5: return .ready
        default: return .idle
        }
    }
}

enum BridgeMessage: Equatable {
    case ready
    case state(Int)
    case progress(current: Double, duration: Double)
    case ended
    case error(String)

    init?(body: Any) {
        guard let dictionary = body as? [String: Any],
              let event = dictionary["event"] as? String else {
            return nil
        }

        switch event {
        case "ready":
            self = .ready

        case "state":
            guard let value = dictionary["data"] as? Int else { return nil }
            self = .state(value)

        case "progress":
            guard let current = dictionary["currentTime"] as? Double,
                  let duration = dictionary["duration"] as? Double else {
                return nil
            }
            self = .progress(current: current, duration: duration)

        case "ended":
            self = .ended

        case "error":
            let message = dictionary["message"] as? String ?? "Unknown player error"
            self = .error(message)

        default:
            return nil
        }
    }
}
