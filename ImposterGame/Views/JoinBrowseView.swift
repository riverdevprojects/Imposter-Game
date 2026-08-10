import SwiftUI

struct JoinBrowseView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.discoveredLobbies.isEmpty {
                    ContentUnavailableCompat(
                        title: "Looking for games…",
                        systemImage: "dot.radiowaves.left.and.right",
                        description: "Make sure the host has started a lobby nearby, and that Bluetooth and Wi-Fi are on."
                    )
                } else {
                    List(model.discoveredLobbies) { lobby in
                        Button {
                            model.requestJoin(lobby)
                        } label: {
                            HStack {
                                Image(systemName: "person.3.fill").foregroundStyle(.tint)
                                VStack(alignment: .leading) {
                                    Text(lobby.lobbyName).font(.headline)
                                    Text("\(lobby.playerCount) player\(lobby.playerCount == 1 ? "" : "s")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Find Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { model.leaveToMainMenu() }
                }
            }
        }
    }
}

/// Small compatibility wrapper so the empty state looks good on older iOS too.
struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
