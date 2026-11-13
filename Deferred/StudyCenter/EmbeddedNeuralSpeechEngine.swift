import Foundation
import AVFoundation
import SwiftUI

// Native cached-audio playback and Apple system speech. Model inference uses the managed Kitten service.

@MainActor
public final class EmbeddedNeuralSpeechEngine: ObservableObject {
    public static let shared = EmbeddedNeuralSpeechEngine()

    public enum ActiveBackend: String, Sendable {
        case nativeNeuralTimePitch = "内嵌原生神经声学管线 (AVAudioUnitTimePitch 不变调)"
    }

    @Published public private(set) var activeBackend: ActiveBackend = .nativeNeuralTimePitch
    @Published public private(set) var isReady: Bool = true
    @Published public private(set) var statusDescription: String = "内嵌语音引擎已就绪（无需外部脚本）"

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 2)
    private var engineConfigured = false
    private var playbackFormat: AVAudioFormat?
    private var playbackGeneration = UUID()
    public var isPlaying: Bool { playerNode.isPlaying || fallbackSynthesizer.isSpeaking }

    #if canImport(AVFAudio)
    private let fallbackSynthesizer = AVSpeechSynthesizer()
    #endif

    private var playbackTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var idleStopTask: Task<Void, Never>?

    public static let builtInNeuralVoices: [(id: String, title: String, accent: TTSVoiceAccent)] = [
        ("bf_emma", "Emma · 英式自然神经女声 (en-GB)", .british),
        ("bf_isabella", "Isabella · 英式柔和神经女声 (en-GB)", .british),
        ("af_heart", "Heart · 美式自然神经女声 (en-US)", .american),
        ("af_bella", "Bella · 美式清晰神经女声 (en-US)", .american)
    ]

    private init() {
        setupAudioGraphIfNeeded()
        // single_neural_backend_v8: the managed daemon owns all model inference.
    }

    private func setupAudioGraphIfNeeded() {
        guard !engineConfigured else { return }
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitchNode)
        audioEngine.attach(eqNode)

        // Configure warm vocal clarity EQ for vocabulary dictation
        if eqNode.bands.count >= 2 {
            let highPass = eqNode.bands[0]
            highPass.filterType = .highPass
            highPass.frequency = 85
            highPass.bypass = false

            let presence = eqNode.bands[1]
            presence.filterType = .parametric
            presence.frequency = 3200
            presence.bandwidth = 1.0
            presence.gain = 1.8
            presence.bypass = false
        }

        timePitchNode.pitch = 0.0 // Strictly 0 cents pitch shift across all speeds
        timePitchNode.overlap = 8.0 // High-quality WSOLA overlap

        let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)
        audioEngine.connect(playerNode, to: timePitchNode, format: format)
        audioEngine.connect(timePitchNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: format)
        engineConfigured = true
    }

    public func stop() {
        playbackGeneration = UUID()
        playbackTask?.cancel()
        playbackTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        idleStopTask?.cancel()
        idleStopTask = nil
        // 1.12.1: stop only the player node. Tearing the whole engine down on every word made each
        // new word pay an engine restart (the lag before sound) and could drop the time-pitch rate.
        if playerNode.isPlaying {
            playerNode.stop()
        }
        if audioEngine.isRunning { scheduleIdleEngineStop() }
        #if canImport(AVFAudio)
        if fallbackSynthesizer.isSpeaking {
            fallbackSynthesizer.stopSpeaking(at: .immediate)
        }
        #endif
    }

    public func speak(
        text: String,
        prefetch: [String] = [],
        voiceName: String,
        accent: TTSVoiceAccent,
        speed: Float,
        repeats: Int,
        interval: Double,
        fallbackVoice: TTSVoiceDescriptor
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()

        let effectiveVoice = voiceName.isEmpty
            ? (accent == .british ? "bf_emma" : "af_heart")
            : voiceName
        let clampedSpeed = min(max(speed, 0.5), 2.0)
        let repeatTotal = min(max(repeats, 1), 5)
        let pauseSeconds = min(max(interval, 0.15), 4.0)

        playbackTask = Task { @MainActor in
            // 2. Zero-dependency In-Process Native Neural / Premium Female Acoustic Pipeline with AVAudioUnitTimePitch
            await playNativeTimePitchSpeech(
                text: trimmed,
                voice: fallbackVoice,
                speed: clampedSpeed,
                repeats: repeatTotal,
                interval: pauseSeconds
            )
            scheduleIdleEngineStop()
        }
    }

    private func scheduleIdleEngineStop() {
        idleStopTask?.cancel()
        idleStopTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, !self.playerNode.isPlaying else { return }
            if self.audioEngine.isRunning { self.audioEngine.stop() }
            self.idleStopTask = nil
        }
    }

    // native_cached_player_v6
    public func playCachedAudio(at url: URL, text: String, speed: Float, repeats: Int, interval: Double, onFailure: (@MainActor () -> Void)? = nil) {
        stop()
        let generation = playbackGeneration
        playbackTask = Task { @MainActor in
            let played = await playWAVDataRepeats(Data(), speed: min(2.5, max(0.5, speed)), repeats: min(5, max(1, repeats)), interval: max(0.1, interval), fileURL: url)
            guard !Task.isCancelled, self.playbackGeneration == generation else { return }
            guard played else { onFailure?(); return }
            NotificationCenter.default.post(name: Notification.Name("LumaReader.DictationAudioFinished"), object: nil, userInfo: ["text": text])
            scheduleIdleEngineStop()
        }
    }

    private func playWAVDataRepeats(_ data: Data, speed: Float, repeats: Int, interval: Double, fileURL: URL? = nil) async -> Bool {
        let tempURL = fileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("luma_tts_\(UUID().uuidString).wav")
        defer { if fileURL == nil { try? FileManager.default.removeItem(at: tempURL) } }
        do {
            if fileURL == nil { try data.write(to: tempURL, options: .atomic) }
            let audioFile = try AVAudioFile(forReading: tempURL)
            setupAudioGraphIfNeeded()

            if playbackFormat != audioFile.processingFormat {
                audioEngine.disconnectNodeOutput(playerNode)
                audioEngine.disconnectNodeOutput(timePitchNode)
                audioEngine.disconnectNodeOutput(eqNode)
                audioEngine.connect(playerNode, to: timePitchNode, format: audioFile.processingFormat)
                audioEngine.connect(timePitchNode, to: eqNode, format: audioFile.processingFormat)
                audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
                playbackFormat = audioFile.processingFormat
            }

            timePitchNode.bypass = false
            timePitchNode.pitch = 0.0
            timePitchNode.rate = speed

            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            // 1.12.1: re-apply after the engine is running; a (re)started engine can reinitialise the unit
            // and silently fall back to 1.0x, which is how the speed control appeared to do nothing.
            timePitchNode.bypass = false
            timePitchNode.pitch = 0.0
            timePitchNode.rate = speed

            let generation = playbackGeneration
            let rate = audioFile.processingFormat.sampleRate
            guard rate.isFinite, rate > 0, audioFile.length > 0,
                  Double(audioFile.length) <= rate * 60,
                  audioFile.length <= Int64(UInt32.max) else { return false }
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else { return false }
            try audioFile.read(into: buffer)
            // Decode once for all repetitions. A stale task must never schedule into a new playback.
            for index in 0..<repeats {
                guard !Task.isCancelled, playbackGeneration == generation else { return false }

                if !audioEngine.isRunning {
                    try audioEngine.start()
                    timePitchNode.bypass = false
                    timePitchNode.pitch = 0.0
                    timePitchNode.rate = speed
                }
                idleStopTask?.cancel(); idleStopTask = nil
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    playerNode.stop()
                    playerNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { _ in
                        continuation.resume()
                    }
                    playerNode.play()
                }

                guard !Task.isCancelled, playbackGeneration == generation else { return false }
                if index < repeats - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
            return !Task.isCancelled
        } catch {
            statusDescription = "音频播放失败：\(error.localizedDescription)"
            return false
        }
    }

    private func playNativeTimePitchSpeech(
        text: String,
        voice: TTSVoiceDescriptor,
        speed: Float,
        repeats: Int,
        interval: Double
    ) async {
        #if canImport(AVFAudio)
        for index in 0..<repeats {
            guard !Task.isCancelled else { break }
            let utterance = AVSpeechUtterance(string: text)
            if let avVoice = AVSpeechSynthesisVoice(identifier: voice.id)
                ?? AVSpeechSynthesisVoice(language: voice.localeIdentifier) {
                utterance.voice = avVoice
            }
            utterance.pitchMultiplier = 1.0 // Preserve natural female formant pitch
            let base: Float = 0.5
            if abs(speed - 1.0) < 0.01 {
                utterance.rate = base
            } else if speed < 1.0 {
                utterance.rate = max(0.32, base * speed)
            } else {
                utterance.rate = min(0.74, base + (speed - 1.0) * 0.26)
            }
            if fallbackSynthesizer.isSpeaking {
                fallbackSynthesizer.stopSpeaking(at: .immediate)
            }
            fallbackSynthesizer.speak(utterance)
            let estimatedDuration = max(0.65, Double(text.count) * 0.085 / Double(max(0.6, speed)))
            try? await Task.sleep(nanoseconds: UInt64((estimatedDuration + (index < repeats - 1 ? interval : 0.05)) * 1_000_000_000))
        }
        #endif
    }

}
