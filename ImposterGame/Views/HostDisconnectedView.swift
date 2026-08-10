import SwiftUI

struct HostDisconnectedView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Host disconnected")
                .font(.title2.weight(.bold))
            Text("The game ended because the host left or went out of range.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                model.leaveToMainMenu()
            } label: {
                Text("Back to Main Menu").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
