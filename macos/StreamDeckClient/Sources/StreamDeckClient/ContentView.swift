import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var showToken = false
    
    var statusColor: Color {
        if appState.lastError != nil && !appState.isConnected { return .red }
        if appState.isConnected { return .green }
        return .secondary
    }
    
    var statusLabel: String {
        if let err = appState.lastError, !appState.isConnected { return err }
        if appState.isConnected { return "Connected" }
        return "Disconnected"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 16) {
                Text("Stream Deck Client")
                    .font(.headline)
                
                // Status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)
                
                GroupBox("Connection") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Host") {
                            TextField("e.g. 10.10.10.66", text: $appState.host)
                                .textFieldStyle(.roundedBorder)
                                .disabled(appState.isConnected)
                        }
                        LabeledContent("Port") {
                            TextField("8765", value: $appState.port, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .disabled(appState.isConnected)
                        }
                        LabeledContent("Client ID") {
                            TextField("mac-client-1", text: $appState.clientId)
                                .textFieldStyle(.roundedBorder)
                                .disabled(appState.isConnected)
                        }
                        LabeledContent("Token") {
                            HStack {
                                if showToken {
                                    TextField("PSK token", text: $appState.token)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(appState.isConnected)
                                } else {
                                    SecureField("PSK token", text: $appState.token)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(appState.isConnected)
                                }
                                Button(action: { showToken.toggle() }) {
                                    Image(systemName: showToken ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(4)
                }
                
                Button(action: { appState.toggleConnection() }) {
                    Label(
                        appState.isConnected ? "Disconnect" : "Connect",
                        systemImage: appState.isConnected ? "wifi.slash" : "wifi"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.isConnected ? .red : .blue)
                
                Spacer()
            }
            .padding()
            .frame(width: 270)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Detail Editor
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Action Editor")
                        .font(.headline)
                    Spacer()
                    Text("\(appState.registeredButtons.count) buttons")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 8)
                
                Divider()
                
                if appState.registeredButtons.isEmpty {
                    Spacer()
                    Text("No buttons configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List($appState.registeredButtons) { $button in
                        ButtonRowView(button: $button, appState: appState)
                    }
                }
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 670, minHeight: 450)
    }
}

struct ButtonRowView: View {
    @Binding var button: ActionDefinition
    var appState: AppState
    
    var slotText: String {
        if let slot = appState.activeAssignments[button.button_id] {
            return "Slot \(slot)"
        }
        return "Unassigned"
    }
    
    var slotColor: Color {
        appState.activeAssignments[button.button_id] != nil ? .green : .secondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "rectangle.on.rectangle")
                    .foregroundColor(.accentColor)
                Text(button.button_id)
                    .font(.subheadline).bold()
                Spacer()
                Text(slotText)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(slotColor.opacity(0.15))
                    .foregroundColor(slotColor)
                    .cornerRadius(4)
            }
            
            HStack {
                Text("Label")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                TextField("Display label", text: Binding(
                    get: { button.label ?? "" },
                    set: { button.label = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .onSubmit { appState.updateButton(button) }
            }
            
            HStack {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                TextField("Base64 asset (optional)", text: Binding(
                    get: { button.iconData ?? "" },
                    set: { button.iconData = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .onSubmit { appState.updateButton(button) }
            }
            
            Text("Press ↩ in a field to push a live StateUpdate to the Deck")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
