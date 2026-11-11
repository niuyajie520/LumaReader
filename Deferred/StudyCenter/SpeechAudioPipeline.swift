import SwiftUI
import Foundation
import AVFAudio
import Combine
import Security

public enum SpeechResourceProfile:String,Codable,CaseIterable,Sendable {
    case lowPower = "省电", balanced = "平衡", quality = "高音质"
    var cacheBytes:Int { switch self { case .lowPower:16*1024*1024; case .balanced:48*1024*1024; case .quality:96*1024*1024 } }
    var lookAhead:Int { switch self { case .lowPower:0; case .balanced:2; case .quality:4 } }
}
public struct SpeechServiceSettings:Codable,Equatable,Sendable {
    public var enabled = false
    public var baseURL = "http://127.0.0.1:8000/v1"
    public var model = ""
    public var voice = "af_heart"
    public var profile:SpeechResourceProfile = .balanced
    public init() {}
    var endpoint:URL? {
        guard baseURL.count<=2048,model.count<=256,voice.count<=256,
              let url = URL(string:baseURL), url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              url.scheme == "https" || (url.scheme == "http" && ["127.0.0.1","localhost","::1"].contains(url.host ?? "")) else { return nil }
        return url
    }
}
public enum SpeechServiceError:LocalizedError {
    case invalidEndpoint, invalidResponse, emptyAudio, modelUnavailable
    public var errorDescription:String? {
        switch self {
        case .invalidEndpoint:"语音服务需要 HTTPS 地址，或本机回环 HTTP 地址。"
        case .invalidResponse:"语音服务返回异常，请检查地址、凭据和模型。"
        case .emptyAudio:"语音服务没有返回有效音频。"
        case .modelUnavailable:"请先连接服务，选择并验证实际可用的语音模型。"
        }
    }
}
public enum SpeechServiceCredential {
    private static func query(_ endpoint:String)->[String:Any] {
        [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"LumaReader.StudySpeech",kSecAttrAccount as String:endpoint]
    }
    public static func load(endpoint:String)->String {
        var q=query(endpoint);q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess,let data=result as? Data else { return "" }
        return String(decoding:data,as:UTF8.self)
    }
    public static func save(_ value:String,endpoint:String)throws {
        let q=query(endpoint)
        if value.isEmpty { SecItemDelete(q as CFDictionary);return }
        let data=Data(value.utf8)
        let status=SecItemUpdate(q as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status==errSecItemNotFound {
            var add=q;add[kSecValueData as String]=data
            let created=SecItemAdd(add as CFDictionary,nil)
            guard created==errSecSuccess else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(created)) };return
        }
        guard status==errSecSuccess else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(status)) }
    }
}

/// Memory-only LRU; authentication and all synthesis inputs participate in the key.
/// URLSession uses an ephemeral configuration so exercise words/credentials aren't put in HTTP disk caches.
actor SpeechAudioCache {
    struct Key:Hashable,Sendable { let endpoint:String;let model:String;let voice:String;let text:String;let speed:Float;let credential:String }
    struct Result:Sendable { let data:Data;let cacheHit:Bool;let milliseconds:Double }
    private let session:URLSession
    private var values:[Key:Data]=[:], order:[Key]=[], inFlight:[Key:Task<Data,Error>]=[:]
    private var limit=48*1024*1024, total=0
    init(session:URLSession = URLSession(configuration:.ephemeral)) { self.session=session }
    func configure(_ bytes:Int) { limit=max(0,bytes);evict() }
    func releaseCachedAudio() { values.removeAll(); order.removeAll(); total = 0 }
    func discard(_ key:Key) {if let data=values.removeValue(forKey:key){total-=data.count};order.removeAll{$0==key}}
    private func evict() {
        while total>limit,let key=order.first { order.removeFirst(); if let data=values.removeValue(forKey:key){total-=data.count} }
    }
    func audio(_ key:Key)throws -> Data { // Strictly synchronous cache lookup, useful for latency tests.
        guard let data=values[key] else { throw SpeechServiceError.emptyAudio };return data
    }
    func fetch(_ key:Key)async throws->Result {
        let start=ContinuousClock.now
        if let data=values[key] {
            order.removeAll{$0==key};order.append(key)
            return Result(data:data,cacheHit:true,milliseconds:Self.ms(start.duration(to:.now)))
        }
        if let pending=inFlight[key] { return Result(data:try await pending.value,cacheHit:false,milliseconds:Self.ms(start.duration(to:.now))) }
        while inFlight.count>=2 {
            try Task.checkCancellation()
            if let pending=inFlight.values.first {_ = try? await pending.value}
            await Task.yield()
        }
        try Task.checkCancellation()
        if let data=values[key] {order.removeAll{$0==key};order.append(key);return Result(data:data,cacheHit:true,milliseconds:Self.ms(start.duration(to:.now)))}
        if let pending=inFlight[key] {return Result(data:try await pending.value,cacheHit:false,milliseconds:Self.ms(start.duration(to:.now)))}
        guard let base=URL(string:key.endpoint) else { throw SpeechServiceError.invalidEndpoint }
        let session=self.session
        let task=Task<Data,Error> {
            var request=URLRequest(url:base.appendingPathComponent("audio/speech"));request.httpMethod="POST";request.timeoutInterval=90
            request.setValue("application/json",forHTTPHeaderField:"Content-Type")
            if !key.credential.isEmpty {request.setValue("Bearer "+key.credential,forHTTPHeaderField:"Authorization")}
            request.httpBody=try JSONSerialization.data(withJSONObject:["model":key.model,"input":key.text,"voice":key.voice,"speed":key.speed,"response_format":"wav"])
            let (data,response)=try await session.data(for:request)
            guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else {throw SpeechServiceError.invalidResponse}
            guard data.count>44,data.count<=16*1024*1024 else {throw SpeechServiceError.emptyAudio}
            return data
        }
        inFlight[key]=task
        do {
            let data=try await task.value;inFlight[key]=nil
            if data.count<=limit {values[key]=data;order.append(key);total+=data.count;evict()}
            return Result(data:data,cacheHit:false,milliseconds:Self.ms(start.duration(to:.now)))
        } catch {inFlight[key]=nil;throw error}
    }
    static func ms(_ duration:Duration)->Double {Double(duration.components.seconds)*1000+Double(duration.components.attoseconds)/1e15}
}

/// Owns all AVAudioPlayer instances off the UI executor. Prepared players are
/// bounded separately from compressed/PCM bytes and are never sent across actors.
private actor SpeechPlaybackDevice {
    private var players:[SpeechAudioCache.Key:AVAudioPlayer]=[:]
    private var order:[SpeechAudioCache.Key]=[]
    private var activeID:UUID?
    private var activeKey:SpeechAudioCache.Key?
    func releaseInactive() {
        for key in Array(players.keys) where key != activeKey { players[key]?.stop(); players[key] = nil }
        order.removeAll { players[$0] == nil }
    }
    func begin(_ id:UUID) {if let key=activeKey{players[key]?.pause()};activeID=id;activeKey=nil}
    func prepare(_ key:SpeechAudioCache.Key,data:Data,limit:Int)throws {
        if players[key]==nil {
            let player=try AVAudioPlayer(data:data)
            guard player.duration<=60,player.prepareToPlay() else{throw SpeechServiceError.emptyAudio}
            players[key]=player
        }
        order.removeAll{$0==key};order.append(key)
        while players.count>max(1,min(5,limit)),let obsolete=order.first(where:{$0 != activeKey}) {
            order.removeAll{$0==obsolete};players[obsolete]?.stop();players[obsolete]=nil
        }
    }
    func play(_ key:SpeechAudioCache.Key,id:UUID)throws {
        guard activeID==id else{throw CancellationError()}
        guard let player=players[key] else{throw SpeechServiceError.emptyAudio}
        activeKey=key;player.currentTime=0
        guard player.play() else{throw SpeechServiceError.emptyAudio}
    }
    func isPlaying(_ id:UUID)->Bool {activeID==id && activeKey.flatMap{players[$0]?.isPlaying} == true}
    func stop(_ id:UUID) {guard activeID==id else{return};if let key=activeKey{players[key]?.pause()};activeID=nil;activeKey=nil}
}

@MainActor final class SpeechAudioPipeline:ObservableObject {
    @Published var models:[String]=[]
    @Published var isConnected=false
    @Published var errorMessage:String?
    @Published var playbackEvidence=""
    private let cache:SpeechAudioCache
    private let session:URLSession
    init(session:URLSession=URLSession(configuration:.ephemeral)) {self.session=session;self.cache=SpeechAudioCache(session:session)}
    @Published private(set) var lastValidationPlayerMS:Double=0
    @Published private(set) var lastCacheHit=false
    @Published private(set) var lastPlayerSubmissionMS:Double=0
    private let device=SpeechPlaybackDevice()
    private var activePlaybackID:UUID?
    private var playback:Task<Void,Never>?, prefetch:Task<Void,Never>?
    private var verifiedEndpoint=""
    private let appleFallback=MacOSSpeechSynthesisManager()
    fileprivate var embeddedBootstrapped=false
    func connect(_ settings:SpeechServiceSettings)async {
        stop();isConnected=false;models=[];errorMessage=nil
        guard let endpoint=settings.endpoint else {errorMessage=SpeechServiceError.invalidEndpoint.localizedDescription;return}
        do {
            var request=URLRequest(url:endpoint.appendingPathComponent("models"));request.timeoutInterval=10
            let credential=SpeechServiceCredential.load(endpoint:settings.baseURL)
            if !credential.isEmpty {request.setValue("Bearer "+credential,forHTTPHeaderField:"Authorization")}
            let (data,response)=try await session.data(for:request)
            guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode),
                  let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],let list=root["data"] as? [[String:Any]] else {throw SpeechServiceError.invalidResponse}
            models=list.compactMap{$0["id"] as? String}.sorted();verifiedEndpoint=settings.baseURL;isConnected=true
        } catch {errorMessage=error.localizedDescription}
    }
    func verify(_ settings:SpeechServiceSettings) async -> Bool {
        guard isConnected,verifiedEndpoint==settings.baseURL,models.contains(settings.model) else {errorMessage=SpeechServiceError.modelUnavailable.localizedDescription;return false}
        let validationKey=key("hello",settings,1)
        do {
            let result=try await cache.fetch(validationKey)
            try await device.prepare(validationKey,data:result.data,limit:settings.profile.lookAhead+1)
            try Task.checkCancellation()
            let validationID=UUID();activePlaybackID=validationID
            await device.begin(validationID)
            let began=ContinuousClock.now
            try await device.play(validationKey,id:validationID)
            lastValidationPlayerMS=SpeechAudioCache.ms(began.duration(to:.now))
            errorMessage=nil;return true
        } catch {await cache.discard(validationKey);errorMessage=error.localizedDescription;return false}
    }
    private func key(_ text:String,_ settings:SpeechServiceSettings,_ speed:Float)->SpeechAudioCache.Key {
        .init(endpoint:settings.baseURL,model:settings.model,voice:settings.voice,text:text,speed:speed,credential:SpeechServiceCredential.load(endpoint:settings.baseURL))
    }
    func play(text:String,next:[String],settings:SpeechServiceSettings,speed:Float,repeats:Int,interval:Double) {
        stop();errorMessage=nil
        guard isConnected,verifiedEndpoint==settings.baseURL,models.contains(settings.model),settings.endpoint != nil else {errorMessage=SpeechServiceError.modelUnavailable.localizedDescription;return}
        let key=key(text,settings,min(1.8,max(0.7,speed)))
        let playbackID=UUID();activePlaybackID=playbackID
        playback=Task { [weak self] in
            guard let self else{return}
            do {
                await device.begin(playbackID)
                await cache.configure(settings.profile.cacheBytes)
                let result=try await cache.fetch(key);try Task.checkCancellation()
                let started=ContinuousClock.now
                try await device.prepare(key,data:result.data,limit:settings.profile.lookAhead+1)
                try Task.checkCancellation()
                for index in 0..<min(5,max(1,repeats)) {
                    try Task.checkCancellation()
                    try await device.play(key,id:playbackID)
                    if index==0 {
                        lastCacheHit=result.cacheHit
                        lastPlayerSubmissionMS=SpeechAudioCache.ms(started.duration(to:.now))
                        playbackEvidence=String(format:"%@ · 音频获取 %.1f ms · 播放器准备/提交 %.1f ms",result.cacheHit ? "缓存命中":"新生成",result.milliseconds,SpeechAudioCache.ms(started.duration(to:.now)))
                        let keys=next.prefix(settings.profile.lookAhead).map{self.key($0,settings,key.speed)}
                        prefetch=Task(priority:.utility) { [cache,device] in
                            for key in keys {
                                if Task.isCancelled{return}
                                if let generated=try? await cache.fetch(key),!Task.isCancelled {
                                    try? await device.prepare(key,data:generated.data,limit:settings.profile.lookAhead+1)
                                }
                            }
                        }
                    }
                    while await device.isPlaying(playbackID) {try await Task.sleep(for:.milliseconds(30))}
                    if index<repeats-1 {try await Task.sleep(for:.seconds(min(5,max(0,interval))))}
                }
            } catch is CancellationError {} catch {await cache.discard(key);errorMessage=error.localizedDescription}
        }
    }
    func releaseUnusedMemory() {
        prefetch?.cancel(); prefetch = nil
        Task { [cache, device] in await cache.releaseCachedAudio(); await device.releaseInactive() }
    }
    func stop() {
        appleFallback.stop()
        EmbeddedNeuralSpeechEngine.shared.stop()
        playback?.cancel();prefetch?.cancel()
        if let id=activePlaybackID {activePlaybackID=nil;Task{await device.stop(id)}}
    }
}


// MARK: - 新版界面调用的兼容入口
extension SpeechAudioPipeline {
    /// 服务已连接并验证 → 使用你配置的自然发音服务（Kokoro 等）；
    /// 否则自动回退到 Apple 系统女声，保证一定有声音，不会静音。
    func play(text:String,next:[String],settings:SpeechServiceSettings,speed:Float,repeats:Int,interval:Double,accent:TTSVoiceAccent,preferredVoiceID:String?) {
        if settings.enabled, isConnected, models.contains(settings.model), settings.endpoint != nil {
            play(text:text,next:next,settings:settings,speed:speed,repeats:repeats,interval:interval)
            return
        }
        stop()
        if settings.enabled, !isConnected {
            Task { [weak self] in await self?.connect(settings) }
        }
        let voices = appleFallback.availableVoices(for: accent)
        let selected = voices.first { $0.id == preferredVoiceID }
        let voice = selected ?? appleFallback.selectBestFemaleVoice(preferredVoiceID: preferredVoiceID, accent: accent)
        appleFallback.repeatCount = repeats
        appleFallback.repeatInterval = interval
        appleFallback.speak(text: text, voice: voice, requestedRate: speed)
    }
}

// MARK: - 听写发音与服务设置（与神经语音面板完全统一的莫奈/玻璃卡片风格）

struct SpeechSettingsPanel: View {
    @ObservedObject var audio: SpeechAudioPipeline
    @Binding var settings: SpeechServiceSettings
    @Binding var voiceID: String
    @Binding var accent: TTSVoiceAccent
    @Binding var rate: Float
    @Binding var repeats: Int
    @Binding var interval: Double
    let voices: [TTSVoiceDescriptor]
    let onClose: () -> Void

    @State private var credential = ""
    @State private var busy = false
    @State private var notice = ""
    @Environment(\.studyAppearance) private var appearance

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .lumaFont(size: 14, weight: .medium)
                .foregroundStyle(appearance.ink)
                .frame(width: 118, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(settings.enabled ? appearance.accent : appearance.ink.opacity(0.38))
                    .frame(width: 7, height: 7)
                Text(settings.enabled ? "已连接外部/本地语音服务：\(settings.baseURL)" : "当前使用 Apple 自然声线与内嵌语音管线")
                    .lumaFont(size: 12)
                    .foregroundStyle(appearance.ink.opacity(0.65))
                    .lineLimit(1)
                Spacer()
                if settings.enabled {
                    Button("切回默认语音") {
                        settings.enabled = false
                        audio.stop()
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 28))
                }
            }

            // 卡片 1：发音与播放参数（与第二张图 KokoroVoiceSettingsSheet 完全一致的圆角卡片与分割线）
            VStack(spacing: 0) {
                settingRow("Apple 口音") {
                    Picker("Apple 口音", selection: $accent) {
                        Text("英式 (en-GB)").tag(TTSVoiceAccent.british)
                        Text("美式 (en-US)").tag(TTSVoiceAccent.american)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                Divider().opacity(0.4)

                settingRow("Apple 声线") {
                    let accentVoices = voices.filter {
                        $0.localeIdentifier.lowercased().replacingOccurrences(of: "_", with: "-").hasPrefix(accent.rawValue.lowercased())
                    }
                    let displayVoices = accentVoices.isEmpty ? voices : accentVoices
                    Picker("Apple 已安装声音", selection: $voiceID) {
                        Text("自动选择自然女声").tag("")
                        ForEach(displayVoices) { voice in
                            Text(voice.displayName + (voice.isFemale ? " · 女声" : " · 其他声线")).tag(voice.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)

                    Button {
                        KokoroNeuralBridge.shared.useAppleSystemSpeech = true
                        KokoroNeuralBridge.shared.stop()
                        let manager = MacOSSpeechSynthesisManager()
                        let chosen = displayVoices.first(where: { $0.id == voiceID })
                            ?? manager.selectBestFemaleVoice(preferredVoiceID: voiceID.isEmpty ? nil : voiceID, accent: accent)
                        manager.repeatCount = 1
                        manager.speak(text: "Luma Reader", voice: chosen, requestedRate: rate)
                    } label: {
                        Label("试听", systemImage: "play.fill")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 30))
                }
                Divider().opacity(0.4)

                settingRow("播报语速") {
                    Slider(value: $rate, in: 0.7...1.8, step: 0.05)
                        .tint(appearance.accent)
                        .frame(width: 220)
                    Text(String(format: "%.2fx", rate))
                        .lumaFont(size: 12.5, design: .monospaced)
                        .foregroundStyle(appearance.accent)
                }
                Divider().opacity(0.4)

                settingRow("单次重复") {
                    Stepper("每个词朗读 \(repeats) 遍", value: $repeats, in: 1...5)
                        .lumaFont(size: 13)
                        .foregroundStyle(appearance.ink)
                }
                Divider().opacity(0.4)

                settingRow("重复间隔") {
                    Slider(value: $interval, in: 0...5, step: 0.1)
                        .tint(appearance.accent)
                        .frame(width: 220)
                    Text(String(format: "%.1f 秒", interval))
                        .lumaFont(size: 12.5, design: .monospaced)
                        .foregroundStyle(appearance.ink.opacity(0.75))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appearance.surface)
            )

            // 卡片 2：兼容语音服务（可选）
            VStack(spacing: 0) {
                settingRow("兼容服务地址") {
                    TextField("http://127.0.0.1:8000/v1", text: $settings.baseURL)
                        .textFieldStyle(.plain)
                        .lumaFont(size: 13, design: .monospaced)
                        .foregroundStyle(appearance.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(appearance.paper.opacity(0.6))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(appearance.line, lineWidth: 1))
                        )
                        .frame(width: 230)

                    Button(busy ? "连接中…" : "连接验证") {
                        busy = true
                        settings.enabled = false
                        Task {
                            do {
                                try SpeechServiceCredential.save(credential, endpoint: settings.baseURL)
                                await audio.connect(settings)
                                if audio.isConnected {
                                    notice = "已连接服务，可选择模型并试听启用。"
                                }
                            } catch {
                                notice = error.localizedDescription
                            }
                            busy = false
                        }
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 30))
                    .disabled(busy)
                }
                Divider().opacity(0.4)

                settingRow("API 密钥") {
                    SecureField("本地服务可留空（保存在钥匙串）", text: $credential)
                        .textFieldStyle(.plain)
                        .lumaFont(size: 13)
                        .foregroundStyle(appearance.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(appearance.paper.opacity(0.6))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(appearance.line, lineWidth: 1))
                        )
                        .frame(width: 230)

                    Picker("缓存模式", selection: $settings.profile) {
                        ForEach(SpeechResourceProfile.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                if audio.isConnected {
                    Divider().opacity(0.4)
                    settingRow("服务模型与声线") {
                        Picker("模型", selection: $settings.model) {
                            Text("选择模型").tag("")
                            ForEach(audio.models, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 150)

                        TextField("声线 ID", text: $settings.voice)
                            .textFieldStyle(.plain)
                            .lumaFont(size: 12.5, design: .monospaced)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(appearance.paper.opacity(0.6)))
                            .frame(width: 100)

                        Button("试听并启用") {
                            busy = true
                            let candidate = settings
                            Task {
                                let valid = await audio.verify(candidate)
                                guard settings == candidate else { notice = "配置已更改，请重新验证。"; busy = false; return }
                                settings.enabled = valid
                                notice = valid ? "验证通过，已启用该语音服务。" : "验证失败，继续使用默认语音。"
                                busy = false
                            }
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: settings.enabled, horizontalPadding: 12, height: 28))
                        .disabled(busy || settings.model.isEmpty)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appearance.surface)
            )

            if let error = audio.errorMessage {
                Text(error)
                    .lumaFont(size: 12)
                    .foregroundStyle(appearance.accent)
                    .lineLimit(1)
            } else if !notice.isEmpty {
                Text(notice)
                    .lumaFont(size: 12)
                    .foregroundStyle(appearance.accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("完成") {
                    onClose()
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 34))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(appearance.paper)
        .foregroundStyle(appearance.ink)
        .onAppear { credential = SpeechServiceCredential.load(endpoint: settings.baseURL) }
        .onChange(of: settings.baseURL) { _, _ in settings.enabled = false }
        .onChange(of: settings.model) { _, _ in settings.enabled = false }
        .onChange(of: settings.voice) { _, _ in settings.enabled = false }
    }
}
