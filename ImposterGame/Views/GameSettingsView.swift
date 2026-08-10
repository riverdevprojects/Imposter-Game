import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject var model: AppModel

    private var connectedCount: Int { model.players.filter { $0.isConnected }.count }
    private var canUseTwoImposters: Bool { connectedCount >= 7 }

    var body: some View {
        Form {
            Section("Category") {
                Picker("Category", selection: $model.settings.category) {
                    Text("Random").tag(LobbySettings.randomCategory)
                    ForEach(model.wordBankCategoryNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }

            Section("Imposters") {
                Stepper(value: $model.settings.imposterCount, in: 1...2) {
                    Text("\(model.settings.imposterCount) imposter\(model.settings.imposterCount > 1 ? "s" : "")")
                }
                .disabled(!canUseTwoImposters)
                if !canUseTwoImposters {
                    Text("2 imposters unlocks with 7+ players.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Imposter word") {
                Toggle("Give imposter a decoy word", isOn: $model.settings.useDecoyWord)
                Text(model.settings.useDecoyWord
                     ? "Imposter sees a related-but-wrong word."
                     : "Blind imposter — no word at all.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Discussion timer") {
                Stepper(value: $model.settings.discussionSeconds, in: 30...300, step: 15) {
                    Text("\(model.settings.discussionSeconds) seconds")
                }
                Text("Players discuss until this runs out — then everyone votes. Discussion can also end early once about half the players tap “Ready to Vote”.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Rules") {
                Label("If the imposter is caught, they must guess the word — a correct guess steals the win.",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button {
                    model.startRound()
                } label: {
                    Label("Start Round", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(connectedCount < 3)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Game Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
