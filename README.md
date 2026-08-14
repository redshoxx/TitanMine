# Titan Mine

Native iPhone idle/tap mining game built with SwiftUI. The project is intentionally dependency-light so it can be packaged as a normal `.ipa` and re-signed by AltStore Classic.

## Included gameplay

- Tap-to-damage boss combat
- Automatic mining damage while the app is open
- Offline coin earnings, capped at 8 hours
- Boss progression with scaling HP and rewards
- Player level + XP progression
- Coins + three mining currencies
- Five upgrade tracks
- TNT special attack
- Six research tracks
- Chest opening with Rare / Epic / Legendary rewards
- Forge progression
- Hero progression
- World map with unlock thresholds
- Quests / daily gift
- Local save via `UserDefaults`
- iPhone portrait UI, haptic feedback, no backend required

## Project layout

- `TitanMine/Models` – data models and game enums
- `TitanMine/Services/GameStore.swift` – game economy, combat, persistence, offline progress
- `TitanMine/Views` – all game screens
- `TitanMine/Components` – shared UI components and visual theme
- `TitanMine/Assets.xcassets` – app icon and battle artwork
- `.github/workflows/build-ios.yml` – macOS GitHub Actions build that produces an unsigned IPA for AltStore re-signing
- `build-altstore.sh` – local macOS build helper

## Build locally on a Mac

Requirements:

- Xcode
- Homebrew
- XcodeGen (`brew install xcodegen`)

Then:

```bash
./build-altstore.sh
```

Output:

```text
TitanMine-AltStore.ipa
```

## Build from GitHub Actions

1. Put this project in a GitHub repository.
2. Open **Actions** → **Build AltStore IPA**.
3. Run the workflow.
4. Download the `TitanMine-AltStore` artifact.
5. Extract the artifact ZIP and use `TitanMine-AltStore.ipa` with AltStore Classic.

## Bundle ID

```text
com.wolfi.titanmine
```

You can change it in `project.yml` before building.

## Current scope

This is a functional first playable build focused on the core loop and UI. It is not yet a production-complete commercial game. Areas for a later production pass include unique animated character sprites, audio, boss-specific attack patterns, a more sophisticated quest state machine, live events, Game Center, analytics, remote balancing and optional cloud save.
