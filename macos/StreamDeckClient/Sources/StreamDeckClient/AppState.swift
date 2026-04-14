import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @AppStorage("hostIp") var host: String = "10.10.10.66"
    @AppStorage("hostPort") var port: Int = 8765
    @AppStorage("presharedToken") var token: String = "secret"
    @AppStorage("clientId") var clientId: String = "mac-client-1"
    
    @Published var isConnected: Bool = false
    
    @Published var lastError: String? = nil
    
    // Core local authoritative models
    @Published var registeredButtons: [ActionDefinition] = [
        ActionDefinition(button_id: "btn_mute", label: "Mute", iconData: nil, preferred_slot: 0, preferred_page: 0),
        ActionDefinition(button_id: "btn_rec", label: "Record", iconData: nil, preferred_slot: 1, preferred_page: 0),
        ActionDefinition(button_id: "btn_stop", label: "Stop", iconData: nil, preferred_slot: 2, preferred_page: 0)
    ]
    
    // Informational mapping logic from server
    @Published var activeAssignments: [String: Int] = [:] // mapping: button_id -> slot
    
    private var client: DeckClient?
    
    func toggleConnection() {
        if isConnected || client != nil {
            disconnect()
        } else {
            lastError = nil
            connect()
        }
    }
    
    private func connect() {
        client = DeckClient(host: host, port: port)
        
        client?.onConnected = { [weak self] in
            guard let self = self else { return }
            self.isConnected = true
            self.lastError = nil
            
            // 1. Authenticate immediately
            // Sanitise token — strip whitespace and any surrounding quote chars that
            // AppStorage may have cached from a previous session (e.g. stored as `"secret"`).
            let cleanToken = self.token
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            print("[AUTH] Sending token: '\(cleanToken)' (raw bytes: \(Array(cleanToken.utf8)))")
            let identify = Envelope(type: "Identify", client_id: self.clientId, payload: IdentifyPayload(token: cleanToken))
            self.client?.send(identify)
            
            // 2. Register all buttons
            let register = Envelope(type: "RegisterActions", client_id: self.clientId, payload: RegisterActionsPayload(actions: self.registeredButtons))
            self.client?.send(register)
            
            // 3. Immediately push all visual States so the server restores UI identically.
            for button in self.registeredButtons {
                let state = Envelope(type: "StateUpdate", client_id: self.clientId, payload: StateUpdatePayload(button_id: button.button_id, label: button.label, iconData: button.iconData))
                self.client?.send(state)
            }
        }
        
        client?.onDisconnect = { [weak self] in
            self?.isConnected = false
            self?.activeAssignments.removeAll()
        }
        
        client?.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        
        client?.connect()
    }
    
    private func disconnect() {
        // Explicitly clear state first so UI updates immediately,
        // regardless of whether the async onDisconnect callback fires.
        isConnected = false
        activeAssignments.removeAll()
        client?.disconnect()
        client = nil
    }
    
    func updateButton(_ button: ActionDefinition) {
        if let index = registeredButtons.firstIndex(where: { $0.button_id == button.button_id }) {
            registeredButtons[index] = button
            
            guard isConnected else { return }
            let state = Envelope(type: "StateUpdate", client_id: clientId, payload: StateUpdatePayload(button_id: button.button_id, label: button.label, iconData: button.iconData))
            client?.send(state)
        }
    }
    
    func handleEvent(_ event: ServerEvent) {
        switch event {
        case .identifyAck(let env):
            print("Identify OK: \(env.payload.status)")
        case .assignmentUpdate(let env):
            activeAssignments.removeAll()
            for assignment in env.payload.assignments {
                activeAssignments[assignment.button_id] = assignment.slot
            }
        case .actionTriggered(let env):
            print("Physical Action Triggered: \(env.payload.button_id)")
        case .error(let env):
            let msg = "[\(env.payload.code)] \(env.payload.message)"
            print("Server Protocol Error: \(msg)")
            self.lastError = msg
            
            if env.payload.code == "superseded" {
                print("Connection superseded by another client instance. Exiting cleanly.")
                exit(0)
            } else if env.payload.code == "auth_failed" {
                // Instantly sever loop to prevent endless bouncing loops
                disconnect()
            }
        case .unknown(let type):
            print("Unknown packet type: \(type)")
        }
    }
}
