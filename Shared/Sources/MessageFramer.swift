import Foundation

/// Encodes/decodes `PeerMessage` values using a 4-byte big-endian length
/// prefix over a TCP byte stream.
enum MessageFramer {
    static func encode(_ message: PeerMessage) throws -> Data {
        let payload = try JSONEncoder().encode(message)
        var length = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(payload)
        return frame
    }

    /// Pulls one complete frame out of `buffer` if available, removing the
    /// consumed bytes. Call repeatedly until it returns nil.
    static func decodeNextFrame(from buffer: inout Data) throws -> PeerMessage? {
        guard buffer.count >= 4 else { return nil }
        let lengthBytes = buffer.prefix(4)
        let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
        let total = 4 + Int(length)
        guard buffer.count >= total else { return nil }
        let payload = buffer.subdata(in: 4..<total)
        buffer.removeSubrange(0..<total)
        return try JSONDecoder().decode(PeerMessage.self, from: payload)
    }
}
