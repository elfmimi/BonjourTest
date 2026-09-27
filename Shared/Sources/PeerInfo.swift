import Network

/// Lightweight, List-friendly wrapper around an `NWBrowser` discovery result.
struct PeerInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let endpoint: NWEndpoint

    init?(result: NWBrowser.Result) {
        guard case let .service(name: name, type: _, domain: _, interface: _) = result.endpoint else {
            return nil
        }
        self.name = name
        self.endpoint = result.endpoint
        self.id = "\(result.endpoint)"
    }

    static func == (lhs: PeerInfo, rhs: PeerInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
