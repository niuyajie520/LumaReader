import Foundation
import Testing
@testable import LumaReader

struct AIImageTests {
    @Test func fiveProvidersSendImageBytesAndDoNotSendPrivateContextWhenDisabled() throws {
        let image = AIImageAttachment(data:Data([1,2,3]),mimeType:"image/png",filename:"figure.png")
        let context = AIReadingContext(bookID:nil,title:"private-title",author:"private-author",chapter:"private-chapter",selectedText:"private-selection",visibleText:"private-page")
        for provider in AIProvider.allCases where provider.supportsImages {
            let request = try AIClient.request(base:provider.baseURL,model:provider.imageModel,key:"fixture-key",history:[AIChatMessage(role:"user",text:"Explain",context:context,image:image)],includeContext:false,provider:provider)
            let body = try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:Any]
            let messages = body["messages"] as! [[String:Any]]
            let blocks = messages.last?["content"] as! [[String:Any]]
            if provider == .claude {
                let source = blocks.first?["source"] as? [String:String]
                #expect(source?["type"] == "base64"); #expect(source?["data"] == "AQID")
                #expect(source?["media_type"] == "image/png")
            } else {
                let imageURL = blocks.first?["image_url"] as? [String:String]
                #expect(imageURL?["url"] == "data:image/png;base64,AQID")
            }
            #expect(!String(decoding:request.httpBody!,as:UTF8.self).contains("private-title"))
            #expect(!String(decoding:request.httpBody!,as:UTF8.self).contains("fixture-key"))
        }
    }
    @Test func textOnlyProviderAndInvalidAttachmentsAreRejected() {
        let image = AIImageAttachment(data:Data([1]),mimeType:"image/png",filename:"figure.png")
        #expect(throws:(any Error).self) { try AIClient.request(base:AIProvider.deepseek.baseURL,model:"text",key:"fixture",history:[AIChatMessage(role:"user",text:"Explain",image:image)],includeContext:false) }
        for data in [Data(),Data(repeating:0,count:4*1024*1024+1)] {
            let invalid = AIImageAttachment(data:data,mimeType:"image/png",filename:"figure.png")
            #expect(throws:(any Error).self) { try AIClient.request(base:AIProvider.openai.baseURL,model:"vision",key:"fixture",history:[AIChatMessage(role:"user",text:"Explain",image:invalid)],includeContext:false,provider:.openai) }
        }
    }
}
