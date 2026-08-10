import SwiftUI

struct RoundResultView: View {
    @EnvironmentObject var model: AppModel
    @State private var guess = ""
    @State private var didSubmitGuess = false

    private var result: RoundResultData? { model.result }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let result {
                    banner(for: result)
                    imposterReveal(result)
                    if !result.awaitingImposterGuess {
                        wordReveal(result)
                    }
                    guessSection(result)
                    breakdown(result)
                } else {
                    ProgressView()
                }

                Spacer(minLength: 8)
                footer(for: result)
            }
            .padding()
        }
    }

    // MARK: State helpers

    /// This device belongs to the caught imposter who owes the mandatory guess.
    private func iAmCaught(_ result: RoundResultData) -> Bool {
        result.caughtPlayerID == model.myID
    }

    // MARK: Sections

    private func banner(for result: RoundResultData) -> some View {
        let title: String
        let color: Color
        let icon: String
        if result.awaitingImposterGuess {
            color = .orange; icon = "questionmark.circle.fill"
            title = iAmCaught(result)
                ? "You were caught — guess the word to steal the win!"
                : "Imposter caught! Waiting for their guess…"
        } else if result.imposterStoleWin {
            title = "Imposter guessed it — imposter steals the win!"; color = .red; icon = "crown.fill"
        } else if result.imposterCaught {
            title = "Imposter caught — players win!"; color = .green; icon = "party.popper.fill"
        } else {
            title = "Imposter escaped — imposter wins!"; color = .red; icon = "eye.slash.fill"
        }
        return VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(color)
            Text(title).font(.title2.weight(.heavy)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    private func imposterReveal(_ result: RoundResultData) -> some View {
        VStack(spacing: 6) {
            Text(result.imposterNames.count > 1 ? "The imposters were" : "The imposter was")
                .font(.caption).foregroundStyle(.secondary)
            Text(result.imposterNames.joined(separator: " & "))
                .font(.title3.weight(.bold))
                .foregroundStyle(.red)
        }
    }

    private func wordReveal(_ result: RoundResultData) -> some View {
        VStack(spacing: 4) {
            Text("Secret word").font(.caption).foregroundStyle(.secondary)
            Text(result.secretWord).font(.title2.weight(.semibold))
            if let decoy = result.decoyWord {
                Text("Decoy was “\(decoy)”").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func guessSection(_ result: RoundResultData) -> some View {
        if result.awaitingImposterGuess {
            if iAmCaught(result) {
                VStack(spacing: 10) {
                    Text("You must guess the real word. Get it right and you steal the win.")
                        .font(.callout).multilineTextAlignment(.center)
                    HStack {
                        TextField("Your guess", text: $guess)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .disabled(didSubmitGuess)
                        Button("Guess") {
                            didSubmitGuess = true
                            model.submitImposterGuess(guess)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(didSubmitGuess || guess.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if didSubmitGuess {
                        Text("Guess submitted — waiting for the result…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ProgressView("Waiting for the caught imposter to guess…")
                    .font(.caption)
            }
        }
    }

    private func breakdown(_ result: RoundResultData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Votes").font(.headline)
            ForEach(sortedBreakdown(result), id: \.0) { id, count in
                HStack {
                    Text(name(for: id))
                    if result.imposterIDs.contains(id) {
                        Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                    Spacer()
                    Text("\(count) vote\(count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private func footer(for result: RoundResultData?) -> some View {
        let awaiting = result?.awaitingImposterGuess ?? false
        VStack(spacing: 8) {
            if model.isHost {
                if awaiting {
                    // Escape hatch: let the host abort if the imposter can't guess.
                    Button(role: .destructive) { model.hostCancelRound() } label: {
                        Label("Cancel Round", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button { model.playAgain() } label: {
                        Label("Play Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else if !awaiting {
                Text("Waiting for the host to start the next round…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Leave Game") { model.leaveToMainMenu() }
                .padding(.top, 4)
        }
    }

    // MARK: Helpers

    private func sortedBreakdown(_ result: RoundResultData) -> [(String, Int)] {
        result.voteBreakdown
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    private func name(for id: String) -> String {
        model.players.first { $0.id == id }?.displayName ?? "Player"
    }
}
