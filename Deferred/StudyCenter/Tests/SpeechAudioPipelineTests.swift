import Foundation
import Testing
@testable import LumaReaderStudyKit

final class SpeechHTTPFixture:URLProtocol,@unchecked Sendable {
    final class State:@unchecked Sendable {
        let lock=NSLock()
        var requests:[URLRequest]=[]
        var status=200
        func reset(status:Int=200){lock.lock();defer{lock.unlock()};requests=[];self.status=status}
        func response(_ request:URLRequest)->(Int,Data){
            lock.lock();defer{lock.unlock()}
            if request.url?.host=="playback.example.invalid" {
                return (200,request.url!.lastPathComponent=="models" ? Data(#"{"data":[{"id":"fixture-tts"}]}"#.utf8):Self.wave)
            }
            requests.append(request)
            if request.url!.lastPathComponent=="models" {return(status,Data(#"{"data":[{"id":"fixture-tts"}]}"#.utf8))}
            return(status,Self.wave)
        }
        var count:Int{lock.lock();defer{lock.unlock()};return requests.count}
        var last:URLRequest?{lock.lock();defer{lock.unlock()};return requests.last}
        static var wave:Data {
            var bytes=Data("RIFF".utf8)
            func u32(_ v:UInt32){var n=v.littleEndian;withUnsafeBytes(of:&n){bytes.append(contentsOf:$0)}}
            func u16(_ v:UInt16){var n=v.littleEndian;withUnsafeBytes(of:&n){bytes.append(contentsOf:$0)}}
            u32(356);bytes.append(Data("WAVEfmt ".utf8));u32(16);u16(1);u16(1);u32(16000);u32(32000);u16(2);u16(16);bytes.append(Data("data".utf8));u32(320);bytes.append(Data(repeating:0,count:320));return bytes
        }
    }
    static let state=State()
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){
        let(status,data)=Self.state.response(request)
        let response=HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:"HTTP/1.1",headerFields:["Content-Type":"audio/wav"])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading(){}
}
@Suite("Speech service cache",.serialized)
struct SpeechAudioPipelineTests {
    private func cache()->SpeechAudioCache {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[SpeechHTTPFixture.self]
        return SpeechAudioCache(session:URLSession(configuration:config))
    }
    private func key(_ text:String="accommodation",voice:String="female",credential:String="fixture-secret")->SpeechAudioCache.Key {
        .init(endpoint:"https://speech.example.invalid/v1",model:"fixture-tts",voice:voice,text:text,speed:1,credential:credential)
    }
    @Test func concurrentRequestsShareGenerationAndWarmHitsAvoidNetwork()async throws {
        SpeechHTTPFixture.state.reset();let cache=cache();let k=key()
        async let a=cache.fetch(k);async let b=cache.fetch(k)
        let first=try await a;let second=try await b
        #expect(first.data==second.data);#expect(SpeechHTTPFixture.state.count==1)
        let warm=try await cache.fetch(k)
        #expect(warm.cacheHit);#expect(warm.data==first.data);#expect(SpeechHTTPFixture.state.count==1)
        #expect(SpeechHTTPFixture.state.last?.value(forHTTPHeaderField:"Authorization")=="Bearer fixture-secret")
        #expect(SpeechHTTPFixture.state.last?.url?.path=="/v1/audio/speech")
    }
    @Test func voiceAndCredentialChangesCannotReuseAnotherAudioEntry()async throws {
        SpeechHTTPFixture.state.reset();let cache=cache()
        _ = try await cache.fetch(key());_ = try await cache.fetch(key(voice:"male"));_ = try await cache.fetch(key(credential:"different"))
        #expect(SpeechHTTPFixture.state.count==3)
    }
    @Test func evictionAndServerFailureDoNotProduceFalseHits()async throws {
        SpeechHTTPFixture.state.reset();let cache=cache();await cache.configure(400)
        _ = try await cache.fetch(key("one"));_ = try await cache.fetch(key("two"))
        let again=try await cache.fetch(key("one"));#expect(!again.cacheHit)
        SpeechHTTPFixture.state.reset(status:401)
        do {_ = try await cache.fetch(key("forbidden"));Issue.record("401 must fail") }catch{}
        SpeechHTTPFixture.state.reset()
        let retry=try await cache.fetch(key("forbidden"));#expect(!retry.cacheHit)
    }
    @Test func endpointPolicyAllowsOnlySecureRemoteOrLoopbackHTTP() {
        var settings=SpeechServiceSettings()
        #expect(settings.endpoint != nil)
        settings.baseURL="http://remote.example.invalid/v1";#expect(settings.endpoint==nil)
        settings.baseURL="https://remote.example.invalid/v1";#expect(settings.endpoint != nil)
        settings.baseURL="https://name:password" + "@" + "remote.example.invalid/v1";#expect(settings.endpoint==nil)
    }
}

@Suite("Speech playback probe",.serialized)
struct SpeechPipelinePlaybackTests {
    @MainActor @Test func verifiedAudioStartsFromWarmCacheAndStops()async throws {
        let live=ProcessInfo.processInfo.environment["LUMA_REAL_SPEECH_URL"]
        let config=URLSessionConfiguration.ephemeral
        if live==nil {config.protocolClasses=[SpeechHTTPFixture.self]}
        let pipeline=SpeechAudioPipeline(session:URLSession(configuration:config))
        var settings=SpeechServiceSettings()
        settings.baseURL=live ?? "https://playback.example.invalid/v1"
        settings.model=ProcessInfo.processInfo.environment["LUMA_REAL_SPEECH_MODEL"] ?? "fixture-tts"
        settings.voice="default"
        await pipeline.connect(settings)
        #expect(pipeline.isConnected)
        let verified=await pipeline.verify(settings);#expect(verified)
        print("SpeechValidationProbe playerSubmissionMS=\(pipeline.lastValidationPlayerMS)")
        pipeline.play(text:"hello",next:[],settings:settings,speed:1,repeats:1,interval:0)
        let deadline=ContinuousClock.now.advanced(by:.seconds(20))
        while pipeline.playbackEvidence.isEmpty && pipeline.errorMessage==nil && ContinuousClock.now<deadline {try await Task.sleep(for:.milliseconds(20))}
        #expect(pipeline.errorMessage==nil)
        #expect(!pipeline.playbackEvidence.isEmpty)
        #expect(pipeline.lastCacheHit)
        #expect(pipeline.lastPlayerSubmissionMS<300)
        print("SpeechPlaybackProbe cacheHit=\(pipeline.lastCacheHit) playerSubmissionMS=\(pipeline.lastPlayerSubmissionMS) realModel=\(live != nil)")
        pipeline.stop()
    }
}
