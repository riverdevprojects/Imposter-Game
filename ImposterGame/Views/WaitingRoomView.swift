import SwiftUI

struct WaitingRoomView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.players.isEmpty {
                    Spacer()
                    ProgressView("Waiting for host to accept…")
                    Spacer()
                } else {
                    VStack(spacing: 6) {
                        Text(model.lobbyName).font(.headline)
                        Text("Waiting for the host to start the round…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    PlayerListView(players: model.players, hostID: hostID)
                }
            }
            .navigationTitle("Waiting Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Leave") { model.leaveToMainMenu() }
                }
            }
        }
    }

    private var hostID: String {
        model.players.first { $0.isHost }?.id ?? ""
    }
}
