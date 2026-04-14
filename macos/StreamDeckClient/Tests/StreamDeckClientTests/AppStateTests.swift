import XCTest
@testable import StreamDeckClient

@MainActor
final class AppStateTests: XCTestCase {
    func testAssignmentMapping() {
        let appState = AppState()
        
        let assignment1 = Assignment(button_id: "btn_mute", slot: 4, page: 0)
        let assignmentEnv = Envelope(type: "AssignmentUpdate", client_id: "test", payload: AssignmentUpdatePayload(assignments: [assignment1]))
        
        appState.handleEvent(.assignmentUpdate(assignmentEnv))
        
        XCTAssertEqual(appState.activeAssignments["btn_mute"], 4)
    }
    
    func testButtonUpdateLogic() {
        let appState = AppState()
        // Default state has Mute
        var btn = appState.registeredButtons.first { $0.button_id == "btn_mute" }!
        btn.label = "Super Mute"
        
        appState.updateButton(btn)
        
        let updatedBtn = appState.registeredButtons.first { $0.button_id == "btn_mute" }!
        XCTAssertEqual(updatedBtn.label, "Super Mute")
    }
}
