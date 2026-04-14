import XCTest
@testable import StreamDeckClient

final class StreamDeckClientTests: XCTestCase {
    
    func testIdentifyPayloadGeneration() throws {
        let envelope = Envelope(type: "Identify", client_id: "test", payload: IdentifyPayload(token: "secret"))
        let data = try JSONEncoder().encode(envelope)
        let jsonStr = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonStr.contains("\"v\":1"))
        XCTAssertTrue(jsonStr.contains("\"type\":\"Identify\""))
        XCTAssertTrue(jsonStr.contains("\"client_id\":\"test\""))
        XCTAssertTrue(jsonStr.contains("\"token\":\"secret\""))
    }
    
    func testIdentifyAckDecoding() throws {
        let json = """
        {
            "v": 1,
            "type": "IdentifyAck",
            "client_id": "test",
            "payload": {
                "status": "ok"
            }
        }
        """.data(using: .utf8)!
        
        let event = MessageDecoder.decode(data: json)
        switch event {
        case .identifyAck(let env):
            XCTAssertEqual(env.payload.status, "ok")
            XCTAssertEqual(env.client_id, "test")
        default:
            XCTFail("Failed to decode IdentifyAck properly")
        }
    }
    
    func testAssignmentUpdateDecoding() throws {
        let json = """
        {
            "v": 1,
            "type": "AssignmentUpdate",
            "client_id": "test",
            "payload": {
                "assignments": [
                    { "button_id": "btn_1", "slot": 0 }
                ]
            }
        }
        """.data(using: .utf8)!
        
        let event = MessageDecoder.decode(data: json)
        switch event {
        case .assignmentUpdate(let env):
            XCTAssertEqual(env.payload.assignments.count, 1)
            XCTAssertEqual(env.payload.assignments.first?.button_id, "btn_1")
            XCTAssertEqual(env.payload.assignments.first?.slot, 0)
        default:
            XCTFail("Failed to decode AssignmentUpdate")
        }
    }
    
    func testUnknownPayloadFallback() throws {
        let json = """
        {
            "v": 1,
            "type": "BogusPacket",
            "client_id": "test",
            "payload": {}
        }
        """.data(using: .utf8)!
        
        let event = MessageDecoder.decode(data: json)
        switch event {
        case .unknown(let type):
            XCTAssertEqual(type, "BogusPacket")
        default:
            XCTFail("Failed to fallback unknown packets")
        }
    }
}
