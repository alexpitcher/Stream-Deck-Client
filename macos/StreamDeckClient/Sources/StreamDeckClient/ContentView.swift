import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar for Config
            VStack(alignment: .leading, spacing: 16) {
                Text("Stream Deck Client")
                    .font(.headline)
                
                GroupBox("Connection") {
                    VStack(alignment: .leading) {
                        TextField("Host IP", text: $appState.host)
                        TextField("Port", value: $appState.port, format: .number)
                        TextField("Client ID", text: $appState.clientId)
                        SecureField("Token", text: $appState.token)
                    }
                    .padding(4)
                }
                
                Button(action: {
                    appState.toggleConnection()
                }) {
                    Text(appState.isConnected ? "Disconnect" : "Connect")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.isConnected ? .red : .blue)
                
                Spacer()
            }
            .padding()
            .frame(width: 250)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Detail Editor
            VStack {
                Text("Action Editor")
                    .font(.headline)
                    .padding(.top)
                
                List($appState.registeredButtons) { $button in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(button.button_id)
                                .font(.subheadline).bold()
                            Spacer()
                            if let slot = appState.activeAssignments[button.button_id] {
                                Text("Assigned to Slot \(slot)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Assigned")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        TextField("Label", text: Binding(
                            get: { button.label ?? "" },
                            set: { button.label = $0.isEmpty ? nil : $0 }
                        ))
                        .onSubmit {
                            appState.updateButton(button)
                        }
                        
                        TextField("Icon Base64 Asset", text: Binding(
                            get: { button.iconData ?? "" },
                            set: { button.iconData = $0.isEmpty ? nil : $0 }
                        ))
                        .onSubmit {
                            appState.updateButton(button)
                        }
                        
                        Text("Hit enter in textfields to push StateUpdates live")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 650, minHeight: 450)
    }
}
