import Foundation
import Network

class DeckClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    private let session: URLSession
    
    // Callbacks for events (dispatched to Main)
    var onEvent: ((ServerEvent) -> Void)?
    var onDisconnect: (() -> Void)?
    var onConnected: (() -> Void)?
    
    // Resilience State
    private var isConnected = false
    private var isIntentionalDisconnect = false
    private var reconnectBackoff: TimeInterval = 1.0
    private let maxBackoff: TimeInterval = 30.0
    
    // Queueing
    private var messageQueue: [String] = []
    
    // Keep-Alive
    private var pingTimer: Timer?
    
    // Reachability
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NWPathMonitorQueue")
    
    init(host: String, port: Int) {
        let urlString = "ws://\(host):\(port)"
        guard let customURL = URL(string: urlString) else {
            fatalError("Invalid URL: \(urlString)")
        }
        self.url = customURL
        self.session = URLSession(configuration: .default)
        
        setupNetworkMonitor()
    }
    
    deinit {
        monitor.cancel()
        pingTimer?.invalidate()
    }
    
    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                // If network comes back and we aren't connected, try aggressively
                DispatchQueue.main.async {
                    if !self.isConnected && !self.isIntentionalDisconnect {
                        self.reconnectBackoff = 1.0 // Reset backoff on network recovery
                        self.connect()
                    }
                }
            } else {
                // Network lost, force disconnect to trigger reconnect-loop logic cleanly
                DispatchQueue.main.async {
                    self.performHardwareDisconnect()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    func connect() {
        isIntentionalDisconnect = false
        
        // Prevent multiple concurrent connects
        if isConnected || webSocketTask != nil { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start receiving
        receiveLoop()
        
        // We consider it "hardware connected" right now, but wait to trigger `onConnected` 
        // until we actually get some verification or just assume connection is open for handshakes.
        isConnected = true
        reconnectBackoff = 1.0 // Reset backoff
        
        startPingTimer()
        
        DispatchQueue.main.async {
            self.onConnected?()
        }
    }
    
    func disconnect() {
        isIntentionalDisconnect = true
        performHardwareDisconnect()
    }
    
    private func performHardwareDisconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        let wasConnected = isConnected
        isConnected = false
        
        if wasConnected {
            DispatchQueue.main.async {
                self.onDisconnect?()
            }
        }
    }
    
    private func scheduleReconnect() {
        guard !isIntentionalDisconnect else { return }
        
        print("Reconnecting in \(reconnectBackoff) seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectBackoff) { [weak self] in
            self?.connect()
        }
        
        // Exponential backoff
        reconnectBackoff = min(reconnectBackoff * 2.0, maxBackoff)
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        
        // Ensure Timer fires on Main RunLoop since we dispatch to main mostly
        DispatchQueue.main.async {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
        }
    }
    
    private func sendPing() {
        guard isConnected else { return }
        
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("Ping failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.performHardwareDisconnect()
                    self?.scheduleReconnect()
                }
            }
        }
    }
    
    // MARK: - Messaging
    
    func send<T: Encodable>(_ message: T) {
        guard let data = try? JSONEncoder().encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("Failed to encode message")
            return
        }
        
        DispatchQueue.main.async {
            if self.isConnected {
                self.sendRaw(jsonString)
            } else {
                // Queue the message if offline
                self.messageQueue.append(jsonString)
                print("Offline. Queued message.")
            }
        }
    }
    
    func flushQueue() {
        DispatchQueue.main.async {
            guard self.isConnected else { return }
            let queue = self.messageQueue
            self.messageQueue.removeAll()
            
            for msg in queue {
                self.sendRaw(msg)
            }
        }
    }
    
    private func sendRaw(_ jsonString: String) {
        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("Send error: \(error.localizedDescription)")
                // Note: Production logic might requeue the message on send failure
            }
        }
    }
    
    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let event = MessageDecoder.decode(data: data) {
                        DispatchQueue.main.async {
                            self.onEvent?(event)
                        }
                    } else {
                        print("Failed to decode text: \(text)")
                    }
                case .data(let data):
                    if let event = MessageDecoder.decode(data: data) {
                        DispatchQueue.main.async {
                            self.onEvent?(event)
                        }
                    } else {
                        print("Failed to decode data")
                    }
                @unknown default:
                    break
                }
                
                // Continue listening
                if self.isConnected {
                    self.receiveLoop()
                }
                
            case .failure(let error):
                let nsError = error as NSError
                DispatchQueue.main.async {
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // Normal disconnect
                    } else {
                        print("Receive error: \(error.localizedDescription)")
                    }
                    
                    self.performHardwareDisconnect()
                    self.scheduleReconnect()
                }
            }
        }
    }
}
