import Foundation
import AVFoundation
import Observation

/// Lightweight `AVAudioPlayer` wrapper for previewing recorded voice notes
/// from the memory detail screen. State is `@Observable` so SwiftUI can
/// drive the play/pause icon and progress bar without `Combine` glue.
@MainActor
@Observable
public final class VoicePlayer {
    public enum State: Equatable, Sendable {
        case idle
        case playing(currentTime: TimeInterval, duration: TimeInterval)
        case paused(currentTime: TimeInterval, duration: TimeInterval)

        public var isPlaying: Bool {
            if case .playing = self { return true }
            return false
        }

        public var progress: Double {
            switch self {
            case .idle: return 0
            case .playing(let current, let duration), .paused(let current, let duration):
                guard duration > 0 else { return 0 }
                return min(1, max(0, current / duration))
            }
        }
    }

    public private(set) var state: State = .idle

    private var player: AVAudioPlayer?
    private var loadedURL: URL?
    private var ticker: Task<Void, Never>?
    private let session: AVAudioSession

    public init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    /// Plays the file at `url`. If the same file is currently paused,
    /// resumes from that position. If a different file is already loaded,
    /// it's replaced.
    public func play(url: URL) {
        if loadedURL == url, let player {
            player.play()
            beginTicking(player: player)
            return
        }

        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
        } catch {
            // Continue anyway — many devices play without explicit session setup.
        }

        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            state = .idle
            return
        }
        player.prepareToPlay()
        guard player.play() else {
            state = .idle
            return
        }

        self.player = player
        self.loadedURL = url
        beginTicking(player: player)
    }

    public func pause() {
        guard let player else { return }
        player.pause()
        ticker?.cancel()
        ticker = nil
        state = .paused(currentTime: player.currentTime, duration: player.duration)
    }

    public func stop() {
        ticker?.cancel()
        ticker = nil
        player?.stop()
        player = nil
        loadedURL = nil
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        state = .idle
    }

    private func beginTicking(player: AVAudioPlayer) {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                if player.isPlaying {
                    self.state = .playing(currentTime: player.currentTime, duration: player.duration)
                } else if player.currentTime >= player.duration - 0.05 {
                    self.stop()
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
