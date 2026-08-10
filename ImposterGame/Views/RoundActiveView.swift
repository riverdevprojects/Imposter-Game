import SwiftUI

struct RoundActiveView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Category")
                .font(.caption).foregroundStyle(.secondary)
            Text(model.currentCategory)
                .font(.title3.weight(.semibold))

            roleCard

            timerView

            Spacer()

            VStack(spacing: 10) {
                if model.readyThreshold > 0 {
                    Text("\(model.readyCount) / \(model.readyThreshold) ready to vote early")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(model.readyCount >= model.readyThreshold ? .green : .secondary)
                }
                Button {
                    model.markReadyToVote()
                } label: {
                    Label(model.iAmReady ? "Ready — waiting for others" : "Ready to Vote",
                          systemImage: model.iAmReady ? "checkmark.circle.fill" : "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.iAmReady)
                .padding(.horizontal, 40)
                Text("Voting starts when the timer runs out, or when enough players are ready.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }

    @ViewBuilder private var roleCard: some View {
        VStack(spacing: 12) {
            if model.myRoleIsImposter {
                Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.red)
                Text("You are the IMPOSTER")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.red)
                if let decoy = model.myWord {
                    Text("Your decoy word")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(decoy).font(.title.weight(.bold))
                    Text("Blend in — it's close, but not the real word.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("You don't know the word.\nBluff from everyone's clues.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("The secret word is")
                    .font(.caption).foregroundStyle(.secondary)
                Text(model.myWord ?? "—")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text("Give a one-word clue on your turn.\nProve you know it — without helping the imposter.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
    }

    private var timerView: some View {
        VStack(spacing: 4) {
            Text(timeString(model.discussionRemaining))
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(model.discussionRemaining <= 10 && model.discussionRemaining > 0 ? .red : .primary)
            Text("Discussion time")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
