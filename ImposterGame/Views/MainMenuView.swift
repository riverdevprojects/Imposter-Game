import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Imposter")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                Text("A local party game for 3–10 players")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Your name")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Name", text: $model.displayName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 40)

            VStack(spacing: 16) {
                Button {
                    model.hostGame()
                } label: {
                    Label("Host a Game", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    model.joinGame()
                } label: {
                    Label("Join a Game", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .disabled(model.displayName.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
            Text("No internet needed · plays over Bluetooth & Wi-Fi")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
