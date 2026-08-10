import SwiftUI

struct VotingView: View {
    @EnvironmentObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    /// You can't vote for yourself.
    private var candidates: [PlayerInfo] {
        model.ballot.filter { $0.id != model.myID && $0.isConnected }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Who is the Imposter?")
                .font(.title2.weight(.bold))
                .padding(.top)

            if model.votesExpected > 0 {
                Text("\(model.votesReceived) / \(model.votesExpected) votes in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(candidates) { player in
                        voteButton(for: player)
                    }
                }
                .padding(.horizontal)
            }

            if model.myVote != nil {
                Label("Vote locked in", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout.weight(.semibold))
            }

            if model.myVote != nil {
                Text(model.isHost
                     ? "Results reveal automatically once everyone has voted."
                     : "Waiting for the host to reveal the results…")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if model.isHost {
                // Escape hatch only — voting ends when all votes are in, so the
                // host can't force an early (imposter-favoring) reveal.
                Button(role: .destructive) {
                    model.hostCancelRound()
                } label: {
                    Label("Cancel Round", systemImage: "xmark.circle")
                }
                .font(.footnote)
                .padding(.top, 2)
            }
        }
        .padding(.bottom)
    }

    private func voteButton(for player: PlayerInfo) -> some View {
        let selected = model.myVote == player.id
        return Button {
            model.castVote(for: player.id)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                Text(player.displayName)
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(selected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
