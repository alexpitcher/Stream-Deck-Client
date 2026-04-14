import Foundation

// MARK: - CommandLine Arguments

var host = "127.0.0.1"
var port = 8765
var token = ""

var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--host":
        if let val = args.popFirst() { host = val }
    case "--port":
        if let val = args.popFirst(), let p = Int(val) { port = p }
    case "--token":
        if let val = args.popFirst() { token = val }
    default:
        break
    }
}

if token.isEmpty {
    print("Warning: No token provided. Use --token YOUR_PSK")
}

let clientId = "mac-client-1"
let client = DeckClient(host: host, port: port)
var hasSentMuteUpdate = false

// MARK: - Event Handling

client.onConnected = {
    print("Socket connected. Authenticating...")
    let identifyMsg = IdentifyMessage(client_id: clientId, token: token)
    client.send(identifyMsg)
}

client.onDisconnect = {
    print("Socket disconnected. DeckClient will attempt to reconnect...")
}

client.onEvent = { event in
    switch event {
    case .identifyAck(let ack):
        if ack.status == "ok" {
            print("Authenticated")
            
            // Flush any offline queued messages
            client.flushQueue()
            
            let registerMsg = RegisterActionsMessage(actions: [
                ActionDefinition(button_id: "btn_mute", label: "Mute"),
                ActionDefinition(button_id: "btn_rec", label: "Rec"),
                ActionDefinition(button_id: "btn_stop", label: "Stop")
            ])
            client.send(registerMsg)
        } else {
            print("Authentication error: \(ack.message ?? "Unknown")")
            // Optional: exit(1) or let it retry if token changes, here we exit since token is static
            exit(1)
        }
        
    case .assignmentUpdate(let update):
        for assignment in update.assignments {
            print("\(assignment.button_id) → slot \(assignment.slot)")
        }
        
    case .actionTriggered(let action):
        print("ActionTriggered: \(action.button_id)")
        if action.button_id == "btn_mute" && !hasSentMuteUpdate {
            hasSentMuteUpdate = true
            let updateMsg = StateUpdateMessage(button_id: "btn_mute", label: "MUTED")
            client.send(updateMsg)
        }
        
    case .error(let error):
        print("Error: \(error.code) — \(error.message)")
        
    case .unknown(let type):
        print("Unknown message type received: \(type)")
    }
}

client.onShutdownComplete = {
    print("Clean disconnect complete. Exiting.")
    exit(0)
}

// MARK: - OS Signal Traps

// Ignore default abrupt kills so GCD can handle the teardown
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigIntSource.setEventHandler {
    print("\nCaught SIGINT. Disconnecting gracefully...")
    client.disconnect()
}
sigIntSource.resume()

let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigTermSource.setEventHandler {
    print("\nCaught SIGTERM. Disconnecting gracefully...")
    client.disconnect()
}
sigTermSource.resume()

// MARK: - Execution

print("Initiating connection to ws://\(host):\(port)...")
client.connect()

// Run the main event loop so the CLI stays alive and can process delegate callbacks
RunLoop.main.run()
