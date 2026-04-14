import Foundation

// MARK: - Base Envelope

struct Envelope<T: Codable>: Codable {
    let v: Int
    let type: String
    let client_id: String
    var req_id: String?
    let payload: T
    
    init(type: String, client_id: String, req_id: String? = nil, payload: T) {
        self.v = 1
        self.type = type
        self.client_id = client_id
        self.req_id = req_id
        self.payload = payload
    }
}

// A generic envelope decoder just to parse out the 'type'
struct AnyDecodableEnvelope: Decodable {
    let v: Int
    let type: String
    let client_id: String?
    let req_id: String?
}

// Host sends flat errors on Auth failures without envelopes or payloads
struct RawErrorMessage: Decodable {
    let v: Int
    let type: String
    let code: String
    let message: String
}

// MARK: - Client -> Host Payloads

struct IdentifyPayload: Codable {
    let token: String
}

struct ActionDefinition: Codable, Identifiable {
    var id: String { button_id } // For SwiftUI
    let button_id: String
    var label: String?
    var iconData: String?       // Base64 encoded asset if any
    var preferred_slot: Int?
    var preferred_page: Int?
}

struct RegisterActionsPayload: Codable {
    let actions: [ActionDefinition]
}

struct StateUpdatePayload: Codable {
    let button_id: String
    var label: String?
    var iconData: String?
}

// MARK: - Host -> Client Payloads

struct IdentifyAckPayload: Codable {
    let status: String
    let message: String?
}

struct Assignment: Codable, Identifiable {
    var id: String { button_id }
    let button_id: String
    let slot: Int
    let page: Int?
}

struct AssignmentUpdatePayload: Codable {
    let assignments: [Assignment]
}

struct ActionTriggeredPayload: Codable {
    let button_id: String
}

struct ErrorPayload: Codable {
    let code: String
    let message: String
}

// MARK: - Internal Transport Types

enum ServerEvent {
    case identifyAck(Envelope<IdentifyAckPayload>)
    case assignmentUpdate(Envelope<AssignmentUpdatePayload>)
    case actionTriggered(Envelope<ActionTriggeredPayload>)
    case error(Envelope<ErrorPayload>)
    case unknown(String)
}

struct MessageDecoder {
    static func decode(data: Data) -> ServerEvent? {
        let decoder = JSONDecoder()
        
        guard let base = try? decoder.decode(AnyDecodableEnvelope.self, from: data) else {
            return nil
        }
        
        switch base.type {
        case "IdentifyAck":
            if let env = try? decoder.decode(Envelope<IdentifyAckPayload>.self, from: data) {
                return .identifyAck(env)
            }
        case "AssignmentUpdate":
            if let env = try? decoder.decode(Envelope<AssignmentUpdatePayload>.self, from: data) {
                return .assignmentUpdate(env)
            }
        case "ActionTriggered":
            if let env = try? decoder.decode(Envelope<ActionTriggeredPayload>.self, from: data) {
                return .actionTriggered(env)
            }
        case "Error":
            if let rawError = try? decoder.decode(RawErrorMessage.self, from: data) {
                // Manually re-wrap the raw flattened error from Host so our system architecture still accepts Envelope syntax
                let simulatedEnv = Envelope(type: "Error", client_id: base.client_id ?? "unknown", payload: ErrorPayload(code: rawError.code, message: rawError.message))
                return .error(simulatedEnv)
            }
        default:
            return .unknown(base.type)
        }
        return nil
    }
}
