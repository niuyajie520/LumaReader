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
        guard let url = URL(string:baseURL), url.user == nil, url.password == nil,
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

@MainActor final class SpeechAudioPipeline:ObservableObject {
    @Published var models:[String]=[]
    @Published var isConnected=false
    @Published var errorMessage:String?
    @Published var playbackEvidence=""
    private let cache:SpeechAudioCache
    private let session:URLSession
    init(session:URLSession=URLSession(configuration:.ephemeral)) {self.session=session;self.cache=SpeechAudioCache(session:session)}
    @Published private(set) var lastCacheHit=false
    @Published private(set) var lastPlayerSubmissionMS:Double=0
    private var player:AVAudioPlayer?
    private var playback:Task<Void,Never>?, prefetch:Task<Void,Never>?
    private var verifiedEndpoint=""
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
        do {
            let result=try await cache.fetch(key("hello",settings,1))
            let sample=try AVAudioPlayer(data:result.data)
            guard sample.prepareToPlay() else {throw SpeechServiceError.emptyAudio}
            errorMessage=nil;return true
        } catch {errorMessage=error.localizedDescription;return false}
    }
    private func key(_ text:String,_ settings:SpeechServiceSettings,_ speed:Float)->SpeechAudioCache.Key {
        .init(endpoint:settings.baseURL,model:settings.model,voice:settings.voice,text:text,speed:speed,credential:SpeechServiceCredential.load(endpoint:settings.baseURL))
    }
    func play(text:String,next:[String],settings:SpeechServiceSettings,speed:Float,repeats:Int,interval:Double) {
        stop();errorMessage=nil
        guard isConnected,verifiedEndpoint==settings.baseURL,models.contains(settings.model),settings.endpoint != nil else {errorMessage=SpeechServiceError.modelUnavailable.localizedDescription;return}
        let key=key(text,settings,min(1.8,max(0.7,speed)))
        playback=Task { [weak self] in
            guard let self else{return}
            do {
                await cache.configure(settings.profile.cacheBytes)
                let result=try await cache.fetch(key);try Task.checkCancellation()
                let started=ContinuousClock.now
                let player=try AVAudioPlayer(data:result.data)
                guard player.prepareToPlay() else {throw SpeechServiceError.emptyAudio}
                self.player=player
                for index in 0..<min(5,max(1,repeats)) {
                    try Task.checkCancellation();player.currentTime=0
                    guard player.play() else {throw SpeechServiceError.emptyAudio}
                    if index==0 {
                        lastCacheHit=result.cacheHit
                        lastPlayerSubmissionMS=SpeechAudioCache.ms(started.duration(to:.now))
                        playbackEvidence=String(format:"%@ · 音频获取 %.1f ms · 播放器准备/提交 %.1f ms",result.cacheHit ? "缓存命中":"新生成",result.milliseconds,SpeechAudioCache.ms(started.duration(to:.now)))
                        let keys=next.prefix(settings.profile.lookAhead).map{self.key($0,settings,key.speed)}
                        prefetch=Task(priority:.utility) { [cache] in
                            for key in keys {if Task.isCancelled{return};_ = try? await cache.fetch(key)}
                        }
                    }
                    while player.isPlaying {try await Task.sleep(for:.milliseconds(30))}
                    if index<repeats-1 {try await Task.sleep(for:.seconds(min(5,max(0,interval))))}
                }
            } catch is CancellationError {} catch {errorMessage=error.localizedDescription}
        }
    }
    func stop() {playback?.cancel();prefetch?.cancel();player?.stop();player=nil}
}
