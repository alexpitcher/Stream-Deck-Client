import XCTest
@testable import StreamDeckClient

final class DeckClientTests: XCTestCase {
    func testOfflineQueueing() {
        let client = DeckClient(host: "127.0.0.1", port: 0)
        
        // Assert we start natively offline
        XCTAssertFalse(client.isConnected)
        
        let mockEnvelope = Envelope(type: "Test", client_id: "mac", payload: ["foo": "bar"])
        client.send(mockEnvelope)
        
        let expectation = XCTestExpectation(description: "Queue flush")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Assert the offline payload was forcibly queued into memory buffer
        XCTAssertEqual(client.messageQueue.count, 1)
        XCTAssertTrue(client.messageQueue.first!.contains("\"type\":\"Test\""))
        XCTAssertTrue(client.messageQueue.first!.contains("\"client_id\":\"mac\""))
    }
}
