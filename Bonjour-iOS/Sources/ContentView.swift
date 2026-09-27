import SwiftUI

struct ContentView: View {
    @StateObject private var engine = BonjourConnection()
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nearby Peers") {
                    if engine.discoveredPeers.isEmpty {
                        Text("Searching…")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.discoveredPeers) { peer in
                            Button {
                                engine.connect(to: peer)
                            } label: {
                                Label(peer.name, systemImage: "dot.radiowaves.left.and.right")
                            }
                        }
                    }
                }

                Section("Status") {
                    statusRow
                }

                Section {
                    Toggle("My Toggle", isOn: $engine.localToggleIsOn)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(engine.remoteIndicatorIsOn ? Color.green : Color.gray)
                            .frame(width: 20, height: 20)
                        Text("Remote indicator")
                    }
                }

                Section("Send a Message") {
                    HStack {
                        TextField("Message", text: $messageText)
                            .onSubmit(sendMessage)
                        Button("Send", action: sendMessage)
                            .disabled(engine.status != .connected || messageText.isEmpty)
                    }
                }

                Section("Received Messages") {
                    if engine.receivedMessages.isEmpty {
                        Text("No messages yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.receivedMessages, id: \.self) { message in
                            Text(message)
                        }
                    }
                }
            }
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
