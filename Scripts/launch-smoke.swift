// Process launch evidence only; no screenshots, text, window titles or user data are read.
import Foundation
import AppKit

@MainActor func report(_ status:String,_ alive:Bool,_ launched:Bool,_ code:Int? = nil) -> Never {
    var value:[String:Any] = ["status":status,"processAlive":alive,"finishedLaunching":launched,"mainWindowVerified":false,"interactionTests":"NOT RUN"]
    if let code { value["errorCode"] = code }
    if let data = try? JSONSerialization.data(withJSONObject:value,options:.sortedKeys), let text = String(data:data,encoding:.utf8) { print(text) }
    exit(status == "PASS" ? 0:1)
}
@MainActor func observeLaunch() {
    guard CommandLine.arguments.count == 2 else { report("FAIL",false,false) }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.activates = false
    NSWorkspace.shared.openApplication(at:URL(fileURLWithPath:CommandLine.arguments[1]),configuration:configuration) { application,error in
        DispatchQueue.main.async {
            guard let application else { report("FAIL",false,false,(error as NSError?)?.code) }
            DispatchQueue.main.asyncAfter(deadline:.now()+3) {
                let alive = !application.isTerminated, launched = application.isFinishedLaunching
                application.terminate()
                report(alive && launched ? "PASS":"FAIL",alive,launched)
            }
        }
    }
    RunLoop.main.run(until:Date().addingTimeInterval(15))
    report("FAIL",false,false)
}
MainActor.assumeIsolated { observeLaunch() }
