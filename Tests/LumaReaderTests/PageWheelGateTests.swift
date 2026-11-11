import Foundation
import Testing
@testable import LumaReader
struct PageWheelGateTests {
    @Test func oneGestureAndLongMomentumTurnOnlyOnce() {
        var gate = PageWheelGate()
        #expect(gate.consume(delta:60,began:true,momentum:false,phased:true,time:0) == nil)
        #expect(gate.consume(delta:60,began:false,momentum:false,phased:true,time:0.05) == 1)
        #expect(gate.consume(delta:200,began:false,momentum:false,phased:true,time:0.7) == nil)
        #expect(gate.consume(delta:300,began:false,momentum:true,phased:true,time:1.5) == nil)
        #expect(gate.consume(delta:-110,began:true,momentum:false,phased:true,time:1.6) == -1)
    }
    @Test func unrelatedSmallGesturesDoNotAccumulate() {
        var gate = PageWheelGate()
        #expect(gate.consume(delta:60,began:true,momentum:false,phased:true,time:0) == nil)
        #expect(gate.consume(delta:60,began:true,momentum:false,phased:true,time:0.1) == nil)
    }
}
