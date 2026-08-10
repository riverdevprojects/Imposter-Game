# Imposter

A local, no-internet party game for **3–10 players** in the same room, built in
Swift + SwiftUI and networked over **MultipeerConnectivity** (Bluetooth + Wi‑Fi
peer discovery — no server, no accounts). One phone hosts and is also a full
player; everyone else joins from their own phone.

This repo implements the v1 described in [`Imposter_GDD.md`](Imposter_GDD.md).

## How it plays

1. The host creates a lobby and starts advertising.
2. Other players browse for nearby lobbies and tap to join (auto‑accepted in v1).
3. The host picks a category and settings, then starts the round.
4. Everyone secretly gets a role: **regular players** all see the same secret
   word; the **imposter** sees no word (or a decoy word, if enabled).
5. Players give one‑word clues out loud, in person, during a discussion timer.
6. Everyone votes in‑app for who they think the imposter is.
7. The host reveals the imposter, the vote breakdown, and who won.
8. "Play Again" keeps the same lobby.

Regular players win by voting out the imposter; the imposter wins by surviving
the vote (and, if the "guess to win" rule is on, by guessing the real word after
being caught).

## Requirements

- Xcode 16 or newer (the project uses file‑system‑synchronized groups).
- iOS 16.0+ on device (supports iOS 16.7). **MultipeerConnectivity peer discovery does not work in
  the iOS Simulator** — run on two or more physical devices to actually play.
- Two or more devices on the same Wi‑Fi network and/or with Bluetooth enabled.

## Build & run

1. Open `ImposterGame.xcodeproj` in Xcode.
2. Select the `ImposterGame` scheme and a physical device.
3. Set your own signing team on the target (Signing & Capabilities) — the bundle
   id is `com.riverdev.ImposterGame`; change it if needed.
4. Build & run on each device. One player taps **Host a Game**, the others tap
   **Join a Game**.

The permission strings for Local Network and Bluetooth (and the Bonjour service
`_imposter-game._tcp/._udp`) are already declared in `ImposterGame/Info.plist`.

## Architecture

Host‑authoritative: the host runs all game logic and is the single source of
truth; clients render what the host broadcasts and send their actions (votes)
back up. See GDD §3.4.

```
ImposterGame/
├── ImposterGameApp.swift        // @main app + RootView screen router
├── Info.plist                   // Local Network / Bluetooth / Bonjour keys
├── App/
│   ├── AppModel.swift           // coordinator: MC + engine + navigation
│   └── DeviceIdentity.swift     // stable per-install player id + name
├── Models/
│   ├── PlayerInfo.swift
│   └── LobbySettings.swift
├── Networking/
│   ├── GameMessage.swift        // Codable envelope + RoundResultData
│   └── MultipeerManager.swift   // advertiser, browser, session, delegates
├── Game/
│   ├── GameEngine.swift         // host: roles, vote tally, results
│   ├── WordBank.swift           // loads categories.json, avoids repeats
│   └── RoundState.swift
├── Views/
│   ├── MainMenuView.swift
│   ├── HostLobbyView.swift
│   ├── GameSettingsView.swift
│   ├── JoinBrowseView.swift
│   ├── WaitingRoomView.swift
│   ├── RoundActiveView.swift
│   ├── VotingView.swift
│   ├── RoundResultView.swift
│   └── HostDisconnectedView.swift
├── Resources/
│   └── categories.json          // 10 categories, 20 words each
└── Assets.xcassets              // AppIcon placeholder + AccentColor
```

### Message protocol

All traffic is a single `Codable` `GameMessage` enum, JSON‑encoded and sent
reliably over `MCSession`. One addition beyond the GDD's protocol: a `hello`
message the client sends on connect so the host can map its transient
`MCPeerID` to the client's stable player id.

## v1 decisions (from GDD §9)

- **Join approval:** auto‑accept every join request.
- **Imposter word:** Blind imposter by default; decoy word is a lobby toggle.
- **Two imposters:** available as a toggle once there are 7+ players.

## Not in v1 (GDD §8)

No Android, no host migration, no in‑app clue capture, no persistence across
launches, no online/remote play, no custom categories.

## Round rules of note

- **Discussion timer is a deadline:** when it runs out the host auto‑advances
  everyone to voting. Discussion can end early once about half the players tap
  **Ready to Vote** (which is also cancelable).
- **Mandatory imposter guess:** if the imposter is voted out, they *must* guess
  the real word before the round resolves. The guess is host‑authoritative
  (works on any phone, not just the host) and the word is withheld from everyone
  until the guess is in. A correct guess steals the win for the imposter.
- **Host can cancel a round:** the host has a Cancel Round control during
  discussion, voting, and the awaiting‑guess reveal to abort back to the lobby
  (e.g. a misdeal, or a caught imposter who can't guess).
- **Screens stay awake** for the whole session so phones don't auto‑lock.

## Notes & limitations

- The `AppIcon` is an empty placeholder — drop in a 1024×1024 image before
  shipping to TestFlight/App Store.
