import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct ImposterGameApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onAppear(perform: keepScreenAwake)
        }
        .onChange(of: scenePhase) { phase in
            // Re-assert whenever we return to the foreground; iOS resets this
            // flag on backgrounding.
            if phase == .active { keepScreenAwake() }
        }
    }

    /// Prevent the phones from auto-locking / sleeping during a game — players
    /// need their role and the timer to stay visible the whole round.
    private func keepScreenAwake() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
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
