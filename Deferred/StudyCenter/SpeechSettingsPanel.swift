import SwiftUI

struct SpeechSettingsPanel:View {
    @ObservedObject var audio:SpeechAudioPipeline
    @Binding var settings:SpeechServiceSettings
    @Binding var voiceID:String
    @Binding var accent:TTSVoiceAccent
    @Binding var rate:Float
    @Binding var repeats:Int
    @Binding var interval:Double
    let voices:[TTSVoiceDescriptor]
    let onClose:()->Void
    @State private var credential=""
    @State private var busy=false
    @State private var notice=""
    @Environment(\.studyAppearance) private var appearance
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {Text("听写专项设置").font(.title2);Spacer();Button("完成",action:onClose).keyboardShortcut(.defaultAction)}
            Form {
                Section("发音与播放") {
                    Picker("Apple 口音",selection:$accent) {Text("英式").tag(TTSVoiceAccent.british);Text("美式").tag(TTSVoiceAccent.american)}
                    Picker("Apple 已安装声音",selection:$voiceID) {
                        Text("自动选择自然女声").tag("")
                        ForEach(voices.filter{$0.localeIdentifier==accent.rawValue}) {voice in Text(voice.displayName+(voice.isFemale ? " · 女声":" · 其他声线")).tag(voice.id)}
                    }
                    Slider(value:$rate,in:0.7...1.8,step:0.05) {Text("语速")}
                    Text(String(format:"%.2f× · 标准机械声音固定 1.0×",rate)).font(.caption)
                    Stepper("重复 \(repeats) 次",value:$repeats,in:1...5)
                    Slider(value:$interval,in:0...5,step:0.1) {Text("重复间隔")}
                    Text(String(format:"间隔 %.1f 秒",interval)).font(.caption)
                }
                Section("本地神经模型 / 可选云服务") {
                    TextField("兼容服务地址（含 /v1）",text:$settings.baseURL)
                    SecureField("API 密钥（本地服务可留空）",text:$credential)
                    Text("凭据保存在 macOS 钥匙串。连接只读取模型列表；验证和播放会向你配置的服务请求语音，云服务可能计费。").font(.caption).foregroundStyle(.secondary)
                    Button(busy ? "连接中…":"保存凭据并连接") {
                        busy=true;settings.enabled=false
                        Task {
                            do {try SpeechServiceCredential.save(credential,endpoint:settings.baseURL);await audio.connect(settings)}
                            catch {notice=error.localizedDescription}
                            busy=false
                        }
                    }.disabled(busy)
                    if audio.isConnected {
                        Picker("服务实际列出的模型",selection:$settings.model) {
                            Text("选择模型").tag("")
                            ForEach(audio.models,id:\.self){Text($0).tag($0)}
                        }
                        TextField("模型声线 ID",text:$settings.voice)
                        Button("验证音频并启用该引擎") {
                            busy=true
                            let candidate=settings
                            Task {
                                let valid=await audio.verify(candidate)
                                guard settings==candidate else {notice="配置已更改，请重新验证。";busy=false;return}
                                settings.enabled=valid
                                notice=valid ? "音频验证通过，已启用。":"验证失败，继续使用 Apple 语音。"
                                busy=false
                            }
                        }.disabled(busy || settings.model.isEmpty)
                    }
                    Toggle("使用已验证服务",isOn:$settings.enabled).disabled(!settings.enabled)
                    if settings.enabled {Button("切回 Apple 系统语音") {settings.enabled=false;audio.stop()}}
                    Picker("资源模式",selection:$settings.profile) {ForEach(SpeechResourceProfile.allCases,id:\.self){Text($0.rawValue).tag($0)}}
                    Text("省电：16 MB 缓存、不预取；平衡：48 MB、预取 2 词；高音质：96 MB、预取 4 词。模型品质由所选服务决定，不会擅自更换模型。").font(.caption).foregroundStyle(.secondary)
                    if let error=audio.errorMessage {Text(error).foregroundStyle(.red).textSelection(.enabled)}
                    if !notice.isEmpty {Text(notice)}
                    if !audio.playbackEvidence.isEmpty {Text(audio.playbackEvidence).font(.caption).textSelection(.enabled)}
                }
            }.formStyle(.grouped)
        }.padding(24).frame(minWidth:560,idealWidth:640,minHeight:560)
            .background(appearance.paper).foregroundStyle(appearance.ink)
            .onAppear {credential=SpeechServiceCredential.load(endpoint:settings.baseURL)}
            .onChange(of:settings.baseURL){_,_ in settings.enabled=false}
            .onChange(of:settings.model){_,_ in settings.enabled=false}
            .onChange(of:settings.voice){_,_ in settings.enabled=false}
    }
}
