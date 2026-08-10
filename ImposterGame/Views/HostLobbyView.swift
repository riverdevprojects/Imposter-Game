import SwiftUI

struct HostLobbyView: View {
    @EnvironmentObject var model: AppModel

    private var connectedCount: Int { model.players.filter { $0.isConnected }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                PlayerListView(players: model.players, hostID: hostID)
                footer
            }
            .navigationTitle("Lobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Leave") { model.leaveToMainMenu() }
                }
            }
        }
    }

    private var hostID: String { model.myID }

    private var header: some View {
        VStack(spacing: 6) {
            Text(model.lobbyName)
                .font(.headline)
            Label("Advertising nearby — players can join now",
                  systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(connectedCount) / 10 players")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(connectedCount >= 3 ? .green : .secondary)
        }
        .padding()
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if connectedCount < 3 {
                Text("Waiting for at least 3 players to join…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            NavigationLink {
                GameSettingsView()
            } label: {
                Label("Game Settings & Start", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(connectedCount < 3)
        }
        .padding()
    }
}

/// Shared roster list used on host and client sides.
struct PlayerListView: View {
    let players: [PlayerInfo]
    let hostID: String

    var body: some View {
        List {
            ForEach(players) { player in
                HStack {
                    Image(systemName: player.isHost ? "crown.fill" : "person.fill")
                        .foregroundStyle(player.isHost ? .yellow : .secondary)
                    Text(player.displayName)
                        .fontWeight(player.isHost ? .semibold : .regular)
                    if player.isHost {
                        Text("Host").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(player.isConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                }
                .opacity(player.isConnected ? 1 : 0.5)
            }
        }
        .listStyle(.insetGrouped)
    }
}
