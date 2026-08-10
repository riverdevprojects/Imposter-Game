import SwiftUI

@main
struct ImposterGameApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

/// Routes to the right screen based on the coordinator's `screen`.
struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            switch model.screen {
            case .mainMenu:        MainMenuView()
            case .hostLobby:       HostLobbyView()
            case .gameSettings:    GameSettingsView()
            case .joinBrowse:      JoinBrowseView()
            case .waitingRoom:     WaitingRoomView()
            case .roundActive:     RoundActiveView()
            case .voting:          VotingView()
            case .roundResult:     RoundResultView()
            case .hostDisconnected: HostDisconnectedView()
            }
        }
        .animation(.default, value: model.screen)
        .overlay(alignment: .top) { bannerView }
    }

    @ViewBuilder private var bannerView: some View {
        if let banner = model.banner {
            Text(banner)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { model.banner = nil }
                    }
                }
        }
    }
}
