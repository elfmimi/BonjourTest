import Foundation

/// Wire-protocol message exchanged between peers over the Bonjour connection.
/// Codable synthesis for enums with associated values (SE-0295) gives us
/// JSON encode/decode for free.
enum PeerMessage: Codable, Equatable {
    case hello(deviceName: String)
    case toggle(isOn: Bool)
    case text(String)
}
