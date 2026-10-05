import AVFoundation
final class BellPlayer {
    private var player: AVAudioPlayer?
    func play() throws {
        guard let url = Bundle.module.url(forResource: "bell", withExtension: "wav") else { throw NSError(domain: "PomodoroAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "종소리 파일을 찾을 수 없어요."]) }
        player = try AVAudioPlayer(contentsOf: url); player?.volume = 0.55; player?.play()
    }
}
