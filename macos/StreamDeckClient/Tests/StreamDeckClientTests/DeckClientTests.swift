import XCTest
@testable import StreamDeckClient

@MainActor
final class DeckClientTests: XCTestCase {
    func testOfflineQueueing() {
        let client = DeckClient(host: "127.0.0.1", port: 0)
        
        XCTAssertFalse(client.isConnected)
        
        let mockEnvelope = Envelope(type: "Test", client_id: "mac", payload: ["foo": "bar"])
        client.send(mockEnvelope)
        
        // Queueing is now synchronous since callers are @MainActor — no RunLoop pump needed
        XCTAssertEqual(client.messageQueue.count, 1)
        XCTAssertTrue(client.messageQueue.first!.contains("\"type\":\"Test\""))
        XCTAssertTrue(client.messageQueue.first!.contains("\"client_id\":\"mac\""))
    }
}
