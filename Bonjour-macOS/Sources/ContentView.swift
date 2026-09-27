import SwiftUI

struct ContentView: View {
    @StateObject private var engine = BonjourConnection()
    @State private var messageText = ""

    var body: some View {
        NavigationSplitView {
            List(engine.discoveredPeers) { peer in
                Button {
                    engine.connect(to: peer)
                } label: {
                    Label(peer.name, systemImage: "dot.radiowaves.left.and.right")
                }
            }
            .navigationTitle("Nearby Peers")
            .frame(minWidth: 200)
        } detail: {
            VStack(alignment: .leading, spacing: 20) {
                statusRow

                Divider()

                Toggle("My Toggle", isOn: $engine.localToggleIsOn)
                    .toggleStyle(.switch)

                HStack(spacing: 8) {
                    Circle()
                        .fill(engine.remoteIndicatorIsOn ? Color.green : Color.gray)
                        .frame(width: 20, height: 20)
                    Text("Remote indicator")
                }

                Divider()

                HStack {
                    TextField("Message", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(sendMessage)
                    Button("Send", action: sendMessage)
                        .disabled(engine.status != .connected || messageText.isEmpty)
                }

                Text("Received messages")
                    .font(.headline)
                List(engine.receivedMessages, id: \.self) { message in
                    Text(message)
                }
            }
            .padding()
            .navigationTitle("BonjourTest")
        }
        .onAppear { engine.start() }
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(engine.status == .connected ? Color.green : (engine.status == .connecting ? Color.orange : Color.red))
                .frame(width: 10, height: 10)
            switch engine.status {
            case .disconnected:
                Text("Not connected")
            case .connecting:
                Text("Connecting…")
            case .connected:
                Text("Connected to \(engine.connectedPeerName ?? "peer")")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        engine.sendText(messageText)
        messageText = ""
    }
}

#Preview {
    ContentView()
}
