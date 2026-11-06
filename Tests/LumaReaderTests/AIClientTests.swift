import Foundation
import Testing
@testable import LumaReader

struct AIClientTests {
    @Test func endpointAcceptsDeepSeekAndVersionedBase() throws {
        #expect(try AIClient.endpoint("https://api.deepseek.com").absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(try AIClient.endpoint("https://api.deepseek.com/v1/").absoluteString == "https://api.deepseek.com/v1/chat/completions")
        #expect(try AIClient.endpoint("https://api.deepseek.com/chat/completions").absoluteString == "https://api.deepseek.com/chat/completions")
    }
    @Test func endpointsRejectPublicPlaintextCredentialsAndQueryKeys() {
        #expect(throws:(any Error).self) { try AIClient.endpoint("http://example.com") }
        #expect(throws:(any Error).self) { try AIClient.endpoint("https://user:secret@example.com") }
        #expect(throws:(any Error).self) { try AIClient.endpoint("https://example.com?key=secret") }
        #expect(throws:(any Error).self) { try AIClient.endpoint("file:///tmp/file") }
    }
    @Test func requestCarriesAuthorizedContextAndConversation() throws {
        let context = AIReadingContext(bookID:UUID(),title:"逻辑学",author:"作者",chapter:"第二章",selectedText:"逻辑需要推敲",visibleText:"附近正文")
        let history = [AIChatMessage(role:"user",text:"解释这句",context:context),AIChatMessage(role:"assistant",text:"上一轮解释"),AIChatMessage(role:"user",text:"请举例",context:context)]
        let request = try AIClient.request(base:"https://api.deepseek.com",model:"deepseek-flash",key:"test-key",history:history,includeContext:true)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField:"Authorization") == "Bearer test-key")
        let body = try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:Any]
        let messages = body["messages"] as! [[String:Any]]
        #expect(messages.count == 4)
        #expect((messages[1]["content"] as? String)?.contains("逻辑学") == true)
        #expect((messages[1]["content"] as? String)?.contains("附近正文") == true)
        #expect(messages[2]["content"] as? String == "上一轮解释")
        #expect(body["stream"] as? Bool == false)
        #expect((body["thinking"] as? [String:String])?["type"] == "disabled")
        #expect(!String(decoding:request.httpBody!,as:UTF8.self).contains("test-key"))
    }
    @Test func disablingContextDoesNotAttachReadingMetadata() {
        let context = AIReadingContext(bookID:nil,title:"private-book",author:"private-author",chapter:"private-chapter",selectedText:"private-quote",visibleText:"private-page")
        let wire = AIClient.wireMessages([AIChatMessage(role:"user",text:"Hello",context:context)],includeContext:false)
        #expect(wire.last?.content == "Hello")
        #expect(!wire.contains { $0.content.contains("private-book") })
    }
    @Test func recentHistoryAndQuestionSizesAreBounded() {
        let history = (0..<40).map { AIChatMessage(role:$0%2 == 0 ? "user":"assistant",text:String(repeating:"x",count:100)) }
        #expect(AIClient.wireMessages(history,includeContext:true).count <= 21)
        let long = AIClient.wireMessages([AIChatMessage(role:"user",text:String(repeating:"问",count:20000))],includeContext:false)
        #expect(long.last?.content.count == 12000)
    }
    @Test func successfulReplyDecodesAndErrorsNeverEchoServerSecrets() throws {
        let reply = Data("{\"choices\":[{\"message\":{\"content\":\"  解释内容 📖  \"}}]}".utf8)
        #expect(try AIClient.decode(reply,status:200) == "解释内容 📖")
        var failure = ""
        do { _ = try AIClient.decode(Data("server-echoes-secret".utf8),status:401) }
        catch { failure = error.localizedDescription }
        #expect(!failure.isEmpty)
        #expect(!failure.contains("server-echoes-secret"))
        #expect(throws:(any Error).self) { try AIClient.decode(Data("{\"choices\":[]}".utf8),status:200) }
    }
    @Test func contextPayloadHasExplicitLimits() {
        let context = AIReadingContext(bookID:nil,title:"Title",author:"Author",chapter:"Chapter",selectedText:String(repeating:"选",count:5000),visibleText:String(repeating:"文",count:7000))
        #expect(context.prompt.filter { $0 == "选" }.count <= 4001)
        #expect(context.prompt.filter { $0 == "文" }.count <= 6005)
        #expect(context.prompt.count < 11000)
    }

    @Test func everyProviderBuildsItsOwnEndpointAndAuthentication() throws {
        #expect(AIProvider.allCases.count == 6)
        for provider in AIProvider.allCases {
            let request = try AIClient.request(base:provider.baseURL,model:provider.model,key:"fixture-key",history:[AIChatMessage(role:"user",text:"解释")],includeContext:false,provider:provider)
            #expect(request.url?.host == URL(string:provider.baseURL)?.host)
            let body = try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:Any]
            #expect(body["model"] as? String == provider.model)
            if provider == .claude {
                #expect(request.url?.path == "/v1/messages")
                #expect(request.value(forHTTPHeaderField:"Authorization") == nil)
                #expect(request.value(forHTTPHeaderField:"x-api-key") == "fixture-key")
                #expect(request.value(forHTTPHeaderField:"anthropic-version") == "2023-06-01")
                #expect(body["system"] is String)
                #expect((body["messages"] as? [[String:String]])?.first?["role"] == "user")
            } else {
                #expect(request.url?.path.hasSuffix("/chat/completions") == true)
                #expect(request.value(forHTTPHeaderField:"Authorization") == "Bearer fixture-key")
                #expect(request.value(forHTTPHeaderField:"x-api-key") == nil)
            }
            if provider != .deepseek { #expect(body["thinking"] == nil) }
            #expect(!String(decoding:request.httpBody!,as:UTF8.self).contains("fixture-key"))
        }
    }
    @Test func openAIUsesModernCompletionLimit() throws {
        let request = try AIClient.request(base:AIProvider.openai.baseURL,model:"",key:"fixture-key",history:[],includeContext:false,provider:.openai)
        let body = try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:Any]
        #expect(body["max_tokens"] == nil)
        #expect(body["max_completion_tokens"] as? Int == 8192)
        #expect(body["model"] as? String == AIProvider.openai.model)
    }
    @Test func claudeDecodesOnlyTextBlocksAndPreservesParagraphs() throws {
        let data = Data(#"{"content":[{"type":"thinking","thinking":"hidden"},{"type":"text","text":"解释一"},{"type":"text","text":"解释二"}]}"#.utf8)
        #expect(try AIClient.decode(data,status:200,provider:.claude) == "解释一\n解释二")
        #expect(throws:(any Error).self) { try AIClient.decode(Data(#"{"content":[]}"#.utf8),status:200,provider:.claude) }
        #expect(try AIClient.endpoint("https://api.anthropic.com/v1/messages",provider:.claude).path == "/v1/messages")
    }
    @Test func keysCannotInjectHTTPHeaders() {
        for provider in AIProvider.allCases {
            #expect(throws:(any Error).self) { try AIClient.request(base:provider.baseURL,model:provider.model,key:"fake\r\nX-Secret: value",history:[],includeContext:false,provider:provider) }
        }
    }
}
