import Foundation
@preconcurrency import Network
#if os(iOS)
import UIKit
#endif

/// Owns Bonjour advertise (NWListener) + browse (NWBrowser) + the single
/// active peer connection (NWConnection), and exposes published state for
/// SwiftUI.
@MainActor
final class BonjourConnection: ObservableObject {
    static let serviceType = "_bonjourtest._tcp"

    enum Status: Equatable {
        case disconnected
        case connecting
        case connected
    }

    // MARK: Published UI state

    @Published private(set) var discoveredPeers: [PeerInfo] = []
    @Published private(set) var status: Status = .disconnected
    @Published private(set) var connectedPeerName: String?
    @Published private(set) var receivedMessages: [String] = []

    /// Bound directly to the local Toggle. Setting it sends the new state to
    /// the peer; it never feeds `remoteIndicatorIsOn`.
    @Published var localToggleIsOn: Bool = false {
        didSet {
            guard oldValue != localToggleIsOn else { return }
            send(.toggle(isOn: localToggleIsOn))
        }
    }

    /// The On/Off indicator. Mutated only by an incoming `.toggle` message
    /// from the remote peer.
    @Published private(set) var remoteIndicatorIsOn: Bool = false

    // MARK: Private networking state

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private let deviceName: String
    private var advertisedServiceName: String?

    init(deviceName: String = BonjourConnection.defaultDeviceName()) {
        self.deviceName = deviceName
    }

    func start() {
        startListening()
        startBrowsing()
    }

    func stop() {
        listener?.cancel()
        browser?.cancel()
        connection?.cancel()
    }

    // MARK: Advertise (server role)

    private func startListening() {
        guard let listener = try? NWListener(using: .tcp) else { return }
        listener.service = NWListener.Service(name: deviceName, type: Self.serviceType)
        advertisedServiceName = deviceName
        listener.newConnectionHandler = { [weak self] newConnection in
            // Guaranteed to run on .main since `listener.start(queue: .main)` below.
            MainActor.assumeIsolated {
                self?.handleIncoming(newConnection)
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func handleIncoming(_ newConnection: NWConnection) {
        // Single-active-connection policy: reject a second peer politely.
        if connection != nil {
            newConnection.cancel()
            return
        }
        setUp(newConnection)
    }

    // MARK: Browse (discovery role)

    private func startBrowsing() {
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: NWParameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            // Guaranteed to run on .main since `browser.start(queue: .main)` below.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.discoveredPeers = results
                    .compactMap { PeerInfo(result: $0) }
                    .filter { $0.name != self.advertisedServiceName }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    // MARK: Connect (user tapped a peer)

    func connect(to peer: PeerInfo) {
        connection?.cancel()
        let newConnection = NWConnection(to: peer.endpoint, using: .tcp)
        setUp(newConnection)
    }

    private func setUp(_ newConnection: NWConnection) {
        connection = newConnection
        status = .connecting
        receiveBuffer.removeAll()
        newConnection.stateUpdateHandler = { [weak self] state in
            // Guaranteed to run on .main since `newConnection.start(queue: .main)` below.
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.status = .connected
                    self.send(.hello(deviceName: self.deviceName))
                    self.send(.toggle(isOn: self.localToggleIsOn))
                case .failed, .cancelled:
                    self.tearDownConnection()
                default:
                    break
                }
            }
        }
        newConnection.start(queue: .main)
        receiveNext()
    }

    private func tearDownConnection() {
        connection = nil
        status = .disconnected
        connectedPeerName = nil
    }

    // MARK: Send

    private func send(_ message: PeerMessage) {
        guard let connection, let frame = try? MessageFramer.encode(message) else { return }
        connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        send(.text(text))
    }

    // MARK: Receive loop

    private func receiveNext() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            // Guaranteed to run on .main since the connection was started with `queue: .main`.
            MainActor.assumeIsolated {
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.receiveBuffer.append(data)
                    self.drainBuffer()
                }
                if isComplete || error != nil {
                    self.tearDownConnection()
                    return
                }
                self.receiveNext()
            }
        }
    }

    private func drainBuffer() {
        while let message = try? MessageFramer.decodeNextFrame(from: &receiveBuffer) {
            switch message {
            case .hello(let name):
                connectedPeerName = name
            case .toggle(let isOn):
                remoteIndicatorIsOn = isOn
            case .text(let text):
                receivedMessages.append("\(connectedPeerName ?? "Peer"): \(text)")
            }
        }
    }

    // MARK: Device naming

    private static func defaultDeviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
}
