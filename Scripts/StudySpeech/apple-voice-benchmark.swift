import Foundation
import AppKit
import AVFAudio

@MainActor final class AppleSpeechProbe:NSObject,@preconcurrency AVSpeechSynthesizerDelegate {
    let synthesizer=AVSpeechSynthesizer()
    let words=["accommodation","infrastructure","fluctuate","sustainable","accommodation"]
    var index=0
    var starts:[Double]=[]
    var requested:ContinuousClock.Instant = .now
    var done=false
    let voice:AVSpeechSynthesisVoice
    init(voice:AVSpeechSynthesisVoice){self.voice=voice;super.init();synthesizer.delegate=self}
    func next(){
        guard index<words.count else{done=true;return}
        let utterance=AVSpeechUtterance(string:words[index]);utterance.voice=voice
        utterance.rate=AVSpeechUtteranceDefaultSpeechRate
        requested = .now;synthesizer.speak(utterance)
    }
    func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didStart utterance:AVSpeechUtterance){
        let d=requested.duration(to:.now)
        starts.append(Double(d.components.seconds)*1000+Double(d.components.attoseconds)/1e15)
    }
    func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didFinish utterance:AVSpeechUtterance){index+=1;next()}
}
try MainActor.assumeIsolated {
    _ = NSApplication.shared
    var reports:[[String:Any]]=[]
    let available=AVSpeechSynthesisVoice.speechVoices()
    for locale in ["en-GB","en-US"] {
        let voices=available.filter{$0.language==locale}.sorted {
            if $0.gender != $1.gender{return $0.gender == .female}
            if $0.quality != $1.quality{return $0.quality.rawValue > $1.quality.rawValue}
            return $0.identifier < $1.identifier
        }
        guard let voice=voices.first else {
            reports.append(["locale":locale,"available":false]);continue
        }
        let probe=AppleSpeechProbe(voice:voice);probe.next()
        let deadline=Date().addingTimeInterval(45)
        while !probe.done && Date()<deadline {RunLoop.current.run(until:Date().addingTimeInterval(0.05))}
        guard probe.done,probe.starts.count==probe.words.count else{throw NSError(domain:"AppleSpeechProbe",code:2,userInfo:[NSLocalizedDescriptionKey:"System speech callbacks incomplete"])}
        let sorted=probe.starts.dropFirst().sorted()
        reports.append(["locale":voice.language,"available":true,"voice":voice.identifier,"quality":voice.quality.rawValue,"startMilliseconds":probe.starts,"warmMedianMS":sorted[sorted.count/2]])
        print("AppleSpeechProbe locale=\(locale) callbackCount=\(probe.starts.count) completed=true")
    }
    guard reports.contains(where:{$0["available"] as? Bool == true}) else{throw NSError(domain:"AppleSpeechProbe",code:1,userInfo:[NSLocalizedDescriptionKey:"No installed UK/US system voices"])}
    let report:[String:Any] = ["method":"real installed Apple UK/US voices; AVSpeechSynthesizer didStart callback latency","voices":reports,"physicalSoundLatency":"NOT MEASURED","fallbackRate":1.0]
    let path=CommandLine.arguments.count>1 ? CommandLine.arguments[1]:"apple-speech.json"
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path),options:.atomic)
}
