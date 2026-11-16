import AVFoundation
import Observation

/// 朗读服务：iPhone 上直接用系统的英语语音（离线、免下载、随系统更新）。
/// 模型侧只保留最轻的那套设置，音量/语速/口音都走这里。
@Observable
@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {

    enum Accent: String, CaseIterable, Identifiable {
        case american = "en-US"
        case british = "en-GB"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .american: return "美式发音"
            case .british: return "英式发音"
            }
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?

    var accent: Accent = .american
    /// 0…1，映射到 AVSpeechUtterance 的 rate。
    var rate: Double = 0.48
    var repeatCount: Int = 1
    private(set) var isSpeaking = false
    /// 最近一次朗读结束的时刻，用来算反应时延。
    private(set) var finishedSpeakingAt: Date?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // 静音拨片打开时也要出声，听写场景下这个必须显式设置。
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
    }

    func speak(_ text: String, repeat times: Int? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        configureAudioSession()
        let count = max(1, times ?? repeatCount)
        for index in 0..<count {
            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = AVSpeechSynthesisVoice(language: accent.rawValue)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(0.5 + rate)
            utterance.pitchMultiplier = 1.0
            utterance.postUtteranceDelay = index == count - 1 ? 0 : 0.35
            isSpeaking = true
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    func onFinish(_ handler: (() -> Void)?) {
        completion = handler
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
                self.finishedSpeakingAt = Date()
                self.completion?()
                self.completion = nil
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.completion = nil
        }
    }
}
