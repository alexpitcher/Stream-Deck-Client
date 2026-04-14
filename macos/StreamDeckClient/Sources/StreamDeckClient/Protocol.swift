import Foundation

// MARK: - Client -> Host Messages

struct IdentifyMessage: Encodable {
    let type = "Identify"
    let client_id: String
    let token: String
}

struct ActionDefinition: Encodable {
    let button_id: String
    let label: String
}

struct RegisterActionsMessage: Encodable {
    let type = "RegisterActions"
    let actions: [ActionDefinition]
}

struct StateUpdateMessage: Encodable {
    let type = "StateUpdate"
    let button_id: String
    let label: String
}

// MARK: - Host -> Client Messages

struct IdentifyAckMessage: Decodable {
    let status: String
    let message: String?
}

struct Assignment: Decodable {
    let button_id: String
    let slot: Int
}

struct AssignmentUpdateMessage: Decodable {
    let assignments: [Assignment]
}

struct ActionTriggeredMessage: Decodable {
    let client_id: String
    let button_id: String
}

struct ErrorMessage: Decodable {
    let code: String
    let message: String
}

// MARK: - Event Types

enum ServerEvent {
    case identifyAck(IdentifyAckMessage)
    case assignmentUpdate(AssignmentUpdateMessage)
    case actionTriggered(ActionTriggeredMessage)
    case error(ErrorMessage)
    case unknown(String)
}

struct MessageDecoder {
    struct BaseMessage: Decodable {
        let type: String
    }
    
    static func decode(data: Data) -> ServerEvent? {
        let decoder = JSONDecoder()
        
        guard let base = try? decoder.decode(BaseMessage.self, from: data) else {
            return nil
        }
        
        switch base.type {
        case "IdentifyAck":
            if let msg = try? decoder.decode(IdentifyAckMessage.self, from: data) {
                return .identifyAck(msg)
            }
        case "AssignmentUpdate":
            if let msg = try? decoder.decode(AssignmentUpdateMessage.self, from: data) {
                return .assignmentUpdate(msg)
            }
        case "ActionTriggered":
            if let msg = try? decoder.decode(ActionTriggeredMessage.self, from: data) {
                return .actionTriggered(msg)
            }
        case "Error":
            if let msg = try? decoder.decode(ErrorMessage.self, from: data) {
                return .error(msg)
            }
        default:
            return .unknown(base.type)
        }
        return nil
    }
}
