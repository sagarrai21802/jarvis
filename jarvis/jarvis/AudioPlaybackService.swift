import AVFoundation
import Foundation

final class AudioPlaybackService: NSObject {
    enum PlaybackError: Error {
        case playerCreationFailed
    }

    private var audioPlayer: AVAudioPlayer?

    func playWAVData(_ data: Data) throws {
        audioPlayer?.stop()

        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            throw PlaybackError.playerCreationFailed
        }
    }
}
