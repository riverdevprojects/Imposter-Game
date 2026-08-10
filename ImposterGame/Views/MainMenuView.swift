import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var model: AppModel
    @State private var showingCategories = false

    private var nameIsEmpty: Bool {
        model.displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.tint)
                    .shadow(color: .accentColor.opacity(0.35), radius: 12, y: 4)
                Text("Imposter")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                Text("A local party game for 3–10 players")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your name", systemImage: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $model.displayName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
            }
            .padding(.horizontal, 32)

            VStack(spacing: 14) {
                Button {
                    model.hostGame()
                } label: {
                    Label("Host a Game", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .primaryAction()

                Button {
                    model.joinGame()
                } label: {
                    Label("Join a Game", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .disabled(nameIsEmpty)

            Button {
                showingCategories = true
            } label: {
                Label("Custom Categories", systemImage: "square.grid.2x2")
                    .font(.subheadline)
            }

            Spacer()
            Text("No internet needed · plays over Bluetooth & Wi-Fi")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .sheet(isPresented: $showingCategories) {
            CategoryManagerView()
        }
    }
}
