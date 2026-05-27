import AVFoundation
import Foundation

enum MediaPlaybackAudioSession {
    static func activateForVideoPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
        try? session.setActive(true, options: [])
    }

    static func deactivateRecordingSession() {
        WordTTSService.shared.stop()
        DictionaryAudioPlayerService.shared.stop()
        activateForVideoPlayback()
    }
}
