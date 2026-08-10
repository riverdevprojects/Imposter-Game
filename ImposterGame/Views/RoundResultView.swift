import SwiftUI

struct RoundResultView: View {
    @EnvironmentObject var model: AppModel
    @State private var guess = ""
    @State private var guessOutcome: String? = nil

    private var result: RoundResultData? { model.result }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let result {
                    banner(for: result)
                    imposterReveal(result)
                    wordReveal(result)
                    guessToWin(result)
                    breakdown(result)
                } else {
                    ProgressView()
                }

                Spacer(minLength: 8)
                footer
            }
            .padding()
        }
    }

    // MARK: Sections

    private func banner(for result: RoundResultData) -> some View {
        let stoleWin = guessOutcome == "won" || result.imposterStoleWin
        let title: String
        let color: Color
        let icon: String
        if stoleWin {
            title = "Imposter stole the win!"; color = .red; icon = "crown.fill"
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

    @ViewBuilder private func guessToWin(_ result: RoundResultData) -> some View {
        if model.settings.imposterGuessToWin,
           result.imposterCaught,
           model.myRoleIsImposter,
           guessOutcome == nil {
            VStack(spacing: 10) {
                Text("You were caught — guess the real word to steal the win:")
                    .font(.callout).multilineTextAlignment(.center)
                HStack {
                    TextField("Your guess", text: $guess)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button("Guess") { evaluateGuess(against: result.secretWord) }
                        .buttonStyle(.borderedProminent)
                        .disabled(guess.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else if let guessOutcome {
            Text(guessOutcome == "won" ? "Correct — you stole it!" : "Wrong guess.")
                .font(.callout.weight(.semibold))
                .foregroundStyle(guessOutcome == "won" ? .green : .secondary)
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

    private var footer: some View {
        Group {
            if model.isHost {
                Button {
                    model.playAgain()
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
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

    private func evaluateGuess(against secret: String) {
        let normalized = guess.trimmingCharacters(in: .whitespaces).lowercased()
        let won = normalized == secret.lowercased()
        guessOutcome = won ? "won" : "lost"
    }
}
