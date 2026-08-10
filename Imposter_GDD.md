# Imposter — Game Design Document

**Platform:** iOS (Swift, SwiftUI)
**Networking:** MultipeerConnectivity (Bluetooth + Wi-Fi peer discovery, no server, no internet required)
**Session model:** Host-authoritative, single host phone, host is also a player
**Monetization:** None. All categories free.

---

## 1. Game Overview

A social party game for 3–10 players in the same room. One phone acts as the **host**, which:
1. Advertises itself over MultipeerConnectivity so nearby phones can find and join it
2. Runs the actual game logic (assigns roles, picks words, tallies votes)
3. Is itself a full player — assigned a role and word like everyone else

Everyone else uses their own phone to **discover the host**, request to join, and play. No shared screen, no server, no accounts.

### Core Loop
1. Host opens app → creates a lobby → starts advertising
2. Other players open app → browse for nearby lobbies → tap to request join
3. Host accepts/rejects join requests → player list updates live on all phones
4. Host picks a category (or random) → taps "Start Round"
5. Game engine (on host) secretly assigns one player as the **Imposter**
6. All non-imposter players receive the same secret word. The Imposter receives no word (or a decoy word — see 4.3)
7. Players take turns saying one word/clue related to the secret word out loud (in person, not in-app)
8. After the discussion phase, all players vote in-app for who they think the Imposter is
9. Host tallies votes → reveals results (Imposter identity, vote breakdown, win/loss)
10. "Play Again" → back to step 4, same lobby persists

---

## 2. Roles

| Role | Knows the word? | Goal |
|---|---|---|
| Regular Player | Yes | Give clues vague enough to not help the Imposter, but clear enough to prove innocence. Vote out the Imposter. |
| Imposter (exactly 1 per round) | No (or gets decoy — configurable) | Blend in, guess the word from others' clues, avoid getting voted out. |

**Win conditions:**
- Regular players win if the Imposter is voted out
- Imposter wins if they survive the vote, OR (optional/configurable) if they correctly guess the secret word when prompted after being caught

---

## 3. Networking Architecture (MultipeerConnectivity)

### 3.1 Roles within MC
- **Host phone:** `MCNearbyServiceAdvertiser` (broadcasts availability) + `MCSession` (manages connections)
- **Joining phones:** `MCNearbyServiceBrowser` (discovers hosts) + send join request via invite

### 3.2 Connection Flow
1. Host taps "Create Lobby" → `MultipeerManager` starts advertising with `discoveryInfo` containing lobby name + current player count
2. Joining player taps "Find Games" → browser lists nearby hosts (show lobby name + player count, live-updating)
3. Player taps a lobby → sends invite request to host via `MCNearbyServiceAdvertiser.StartAdvertisingPeer` invite handler
4. Host receives `didReceiveInvitationFromPeer` → **auto-flow decision (see open question below)**: either auto-accept (simplest) or show host an "Accept/Reject" prompt per player
5. On accept, both sides get a connected `MCSession` peer
6. Host sends a `PlayerListUpdate` message to all connected peers whenever the roster changes

### 3.3 Message Protocol
All messages are `Codable` structs wrapped in a single envelope enum, JSON-encoded, sent via `session.send(_:toPeers:with:.reliable)`.

```swift
enum GameMessage: Codable {
    case playerListUpdate(players: [PlayerInfo])
    case roundStart(category: String)
    case roleAssignment(isImposter: Bool, word: String?) // word is nil for imposter unless decoy mode
    case startVoting
    case castVote(voterID: String, votedForID: String)
    case roundResult(imposterID: String, imposterName: String, voteBreakdown: [String: Int], imposterCaught: Bool)
    case playAgainRequest
    case error(message: String)
}

struct PlayerInfo: Codable, Identifiable {
    let id: String       // stable UUID per peer, generated on first launch
    let displayName: String
    var isHost: Bool
    var isConnected: Bool
}
```

### 3.4 Host-Authoritative State
The host is the single source of truth. All game state (current round, roles, votes) lives in a `GameEngine` class that only runs meaningfully on the host device. Client phones are largely "dumb" — they render whatever state the host broadcasts and send user actions (votes) back up.

**Why:** avoids state-sync/conflict issues you'd get from a mesh/peer-to-peer authority model. Simple, reliable, good enough for a party game with ≤10 players.

### 3.5 Disconnection Handling
- If a non-host player disconnects mid-round: host marks them inactive, game continues, their vote (if not yet cast) is excluded from tally
- If the host disconnects: session ends for everyone — show all clients a "Host disconnected" screen with option to return to main menu. (v1 does NOT need host migration — out of scope, see section 8)

---

## 4. Game Content & Rules

### 4.1 Categories & Word Bank
- Ships as a bundled local JSON file, no network/server needed
- Structure:
```json
{
  "categories": [
    {
      "name": "Animals",
      "words": ["Elephant", "Penguin", "Giraffe", "..."]
    },
    {
      "name": "Movies",
      "words": ["Titanic", "Inception", "..."]
    }
  ]
}
```
- Host selects a category (or "Random" pulls from all categories) before each round
- Word is randomly selected from the chosen category, excluding words used in the last N rounds of the session (avoid immediate repeats)

### 4.2 Player Count
- Minimum 3 players (2 regular + 1 imposter)
- Maximum 10 (soft cap based on MultipeerConnectivity practical session size — this framework doesn't hard-limit but reliability degrades in large mesh sessions; 8 is the recommended practical ceiling, 10 as a stretch max)
- For player counts ≥ 7, host can optionally enable **2 Imposters** (configurable toggle)

### 4.3 Imposter Word Handling (configurable, pick one for v1)
- **Option A — Blind Imposter (recommended for v1):** Imposter gets no word at all, just knows they're the Imposter. Must bluff entirely from context.
- **Option B — Decoy Word:** Imposter gets a related-but-wrong word (e.g., real word "Elephant," decoy "Rhino") to make bluffing easier and games less immediately obvious.
- Recommend building the data model to support both (the `word: String?` field in `roleAssignment` already does this) and expose it as a lobby setting toggle, defaulting to Option A for v1 simplicity.

### 4.4 Turn Order / Clue Phase
- v1 scope: **this happens verbally, in person, out of app.** The app just shows a "Discussion Phase" screen with a timer (host-configurable, default 60–90 sec) and the word (or lack thereof).
- Not in v1 scope: enforcing turn order or capturing spoken clues in-app.

### 4.5 Voting
- After discussion timer ends (or host manually advances), app shows a "Vote Now" screen to all players simultaneously
- Each player taps one other player's name/avatar
- Host tallies as votes arrive, shows live "X/Y votes in" count
- Once all votes are in (or host force-ends voting), reveal screen shows: who the Imposter was, vote breakdown per player, and result (caught / not caught)
- If Option A "guess to win" rule is enabled: if caught, Imposter gets one attempt to guess the real word in-app before final result

---

## 5. Screens / UI Flow

```
MainMenu
 ├─ "Host a Game" → HostLobbyView → GameSettingsView → RoundActiveView (loop) → RoundResultView
 └─ "Join a Game" → JoinBrowseView → WaitingRoomView → RoundActiveView (loop) → RoundResultView
```

| Screen | Shown to | Contents |
|---|---|---|
| `MainMenu` | Everyone | Host / Join buttons, app title |
| `HostLobbyView` | Host only | Player list as they join, lobby name, "Start Advertising" toggle, accept/reject incoming join requests (if manual accept chosen) |
| `GameSettingsView` | Host only | Category picker, # of imposters, decoy word toggle, discussion timer length |
| `JoinBrowseView` | Joiners only | List of nearby lobbies (name + player count), tap to request join |
| `WaitingRoomView` | Joiners only | "Waiting for host to accept" → then shared player list once in |
| `RoundActiveView` | Everyone | Your role/word (private), discussion timer, "Ready to Vote" button |
| `VotingView` | Everyone | Tap-to-vote grid of players, live vote count |
| `RoundResultView` | Everyone | Imposter reveal, vote breakdown, win/loss banner, "Play Again" (host) / "Waiting for host" (others) |

---

## 6. Data Models Summary

```swift
struct PlayerInfo: Codable, Identifiable { ... }        // see 3.3
enum GameMessage: Codable { ... }                        // see 3.3

struct LobbySettings: Codable {
    var category: String          // or "Random"
    var imposterCount: Int        // 1 or 2
    var useDecoyWord: Bool
    var discussionSeconds: Int
    var imposterGuessToWin: Bool
}

struct RoundState {
    var players: [PlayerInfo]
    var imposterIDs: Set<String>
    var secretWord: String
    var decoyWord: String?
    var votes: [String: String]   // voterID: votedForID
    var phase: RoundPhase         // .lobby, .discussion, .voting, .results
}
```

---

## 7. Project Structure (for Claude Code)

```
ImposterGame/
├── ImposterGameApp.swift
├── Networking/
│   ├── MultipeerManager.swift      // advertiser, browser, session, delegate callbacks
│   └── GameMessage.swift           // Codable envelope + payload structs
├── Game/
│   ├── GameEngine.swift            // host-side: round lifecycle, role assignment, vote tally
│   ├── WordBank.swift              // loads categories.json, tracks recent words
│   └── RoundState.swift
├── Views/
│   ├── MainMenuView.swift
│   ├── HostLobbyView.swift
│   ├── GameSettingsView.swift
│   ├── JoinBrowseView.swift
│   ├── WaitingRoomView.swift
│   ├── RoundActiveView.swift
│   ├── VotingView.swift
│   └── RoundResultView.swift
├── Models/
│   ├── PlayerInfo.swift
│   └── LobbySettings.swift
└── Resources/
    └── categories.json
```

---

## 8. Explicit Non-Goals for v1 (keep scope tight)

- No Android version
- No host migration if host disconnects mid-game
- No in-app voice/turn capture — clue-giving is verbal, out of app
- No accounts, no persistence across app launches (fresh lobby every session)
- No online/remote play — local proximity (Bluetooth/Wi-Fi range) only
- No custom category creation in v1 (nice follow-up feature, not blocking)

---

## 9. Open Decisions Before Coding Starts

1. **Join approval:** auto-accept anyone who requests, or does host manually tap Accept per player? (Recommend: auto-accept for v1 — fewer taps, faster games. Manual accept can be a v2 toggle for "private lobby" mode.)
2. **Imposter word mode default:** Blind (Option A) vs Decoy (Option B) — recommend Blind for v1, exposed as a settings toggle either way.
3. **App name/bundle ID** and whether this needs to go through TestFlight/App Store or stays a personal sideload.

---

## 10. Build Order (suggested milestones for Claude Code)

1. **M1 — Networking skeleton:** MultipeerManager with advertise/browse/connect working, player list syncing across 2 test devices, no game logic yet.
2. **M2 — Lobby & settings:** HostLobbyView, GameSettingsView, JoinBrowseView, WaitingRoomView fully wired to M1.
3. **M3 — Core round logic:** GameEngine role assignment, word bank loading, RoundActiveView showing correct word/role per player.
4. **M4 — Voting & results:** VotingView, vote tally on host, RoundResultView with reveal.
5. **M5 — Polish:** Play Again loop, disconnect handling, discussion timer, 2-imposter mode, decoy word toggle.
