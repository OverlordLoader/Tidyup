# Tidy Up!

A colorful hybrid-casual **color-sort puzzle** game for iOS. Sort mixed liquids so every tube holds a single color. Calming, juicy, and built to hook: instant readability, visible progress on every move, satisfying completion payoffs — no timers, no fail states.

- **Stack:** native iOS, SwiftUI + SpriteKit, iOS 17+
- **Bundle ID:** `app.tidyup.game`
- **Monetization:** hybrid ads (AdMob) + IAP (StoreKit 2), all billing through Apple

## Monetization setup (for Henry)

The code is complete. These dashboard steps can't be done from code:

**App Store Connect — in-app purchases** (create exactly these product IDs):

| Product ID | Type | Price | What it does |
|---|---|---|---|
| `app.tidyup.game.removeads` | Non-consumable | $4.99 | Remove Ads — disables all ads immediately |
| `app.tidyup.game.boosters.magicpour5` | Consumable | $0.99 | Pack of 5 Magic Pour boosters (auto-completes a tube) |

Steps: App Store Connect → your app → Monetization → In-App Purchases → create each product with the exact ID above, matching type and price → submit with the app version. Sandbox testing works in TestFlight with a sandbox Apple ID.

**AdMob checklist** (apps.admob.com):

1. Create an AdMob account and add the **Tidy Up!** app (iOS, bundle `app.tidyup.game`).
2. Create one **Rewarded** ad unit and one **Interstitial** ad unit.
3. In `Game/AdsManager.swift`, replace the two `TODO(Henry)` placeholder IDs in the `#else` (release) branch with your real IDs.
4. In `Info.plist`, replace the `GADApplicationIdentifier` test value with your real AdMob app ID.
5. Verify banking/identity in your AdMob account — Google pays monthly once you cross $100.

**How it behaves:** debug builds show Google's test ads automatically. Release builds show real ads only after Henry completes the steps above (until then the placeholder IDs simply fail to load — gameplay is unaffected). Buying Remove Ads disables every ad instantly. Interstitials show at most every 3rd level win, never during a new player's first 3 wins, never mid-level.

**Privacy:** `PrivacyInfo.xcprivacy` now declares Device ID collected for third-party advertising (no tracking — no IDFA is used). In App Store Connect's privacy section, answer the advertising-identifier questions to match.

## Play it

Open `ios/App/App.xcodeproj` in Xcode 26+, pick the **App** scheme, run on a device or simulator (iPhone, portrait).

## Official app icon

The approved three-tube artwork is stored in `artwork/app-icon.png` (1024×1024, opaque RGB PNG). The app's `AppIcon` asset catalog contains all eight iPhone size/scale entries plus the App Store marketing icon. iOS applies its own rounded corners.

To regenerate the catalog from the approved master, install Pillow and run `python scripts/generate_icons.py`. The generator resizes the approved image; it does not redraw or replace the design. A new app build is required for the icon to appear on installed devices and the App Store.

## Project layout

```
ios/App/App/
├── TidyUpApp.swift            # App entry
├── Info.plist
├── PrivacyInfo.xcprivacy      # Declares Device ID for third-party advertising (no tracking)
├── Assets.xcassets/           # AppIcon, AccentColor, LaunchBackground
└── Game/
    ├── Palette.swift          # 10-color candy palette (SwiftUI + SpriteKit)
    ├── Models.swift           # TubeState, pour rules (single source of truth)
    ├── LevelGenerator.swift   # Seeded, guaranteed-solvable level generator
    ├── GameEngine.swift       # Rules/state (ObservableObject), emits GameEvents
    ├── SoundManager.swift     # Runtime-synthesized SFX (no audio assets)
    ├── Haptics.swift          # Taptic accents
    ├── ProgressStore.swift    # Unlocked levels + stars in UserDefaults
    ├── AdsManager.swift       # Google Mobile Ads: rewarded + interstitial, pacing rules
    ├── StoreManager.swift     # StoreKit 2: products, purchase, restore, entitlements
    └── Views/
        ├── ContentView.swift      # Title screen, How to play, Settings gear
        ├── LevelSelectView.swift  # 50 levels, stars, locks, Settings gear
        ├── GameView.swift         # HUD, controls (Undo/Magic/Rewind/Restart), win overlay
        ├── BoardScene.swift       # SpriteKit playfield + animations
        ├── TubeNode.swift         # Glossy tube rendering + procedural textures
        └── SettingsView.swift     # Store: Remove Ads, Magic Pour pack, Restore Purchases
scripts/
├── apple-release.py           # Signing/validation (shared pattern + tidyup bundle)
├── apple-release-test.py      # Release-safety unit tests (runs on PR / ubuntu)
├── generate_project.py        # Regenerates project.pbxproj + App.xcscheme
└── generate_icons.py          # Regenerates the AppIcon set (PIL)
```

## Release pipeline

`.github/workflows/apple-release.yml` mirrors the other OverlordLoader apps:

- **PR:** `release-safety` job runs `scripts/apple-release-test.py` on ubuntu.
- **Manual dispatch** (`workflow_dispatch`, `main` branch only): `signed-release` builds the signed IPA on `macos-latest` via the `app-store-release` environment and optionally uploads to App Store Connect (validation only — never submits for review).

Two deliberate adaptations vs. the sibling apps:

1. `scripts/apple-release.py` `ALLOWED` gains `app.tidyup.game` (one-line allowlist addition — needs Henry's review like any signing change).
2. No Node/Capacitor steps — this is a pure native app, so the workflow goes straight from checkout to `apple-release.py`.

**Before the first release dispatch, Henry must:** create an App Store provisioning profile for `app.tidyup.game` (team 5U37FQG3VS) in the Apple Developer portal and add its base64 to the `app-store-release` environment secrets (`APPLE_PROFILE_BASE64`, alongside the existing P12 / App Store Connect key secrets).

## Game design notes

**Addiction formula (built in):** instant readability (level 1 teaches itself in seconds, zero text), visible progress per move, cognitive itch (mixed tubes *feel* wrong), near-completion pressure, low-stakes recovery (unlimited undo, restart, no timers), satisfying closure (star-burst tube completions, confetti level wins).

**Levels:** 50, deterministic per index (seeded RNG — identical on every device, no storage). Generated by reverse-shuffling from the solved state, so every level is solvable by construction. Ramp: 3 colors + 2 spare tubes → 8 colors + 1 spare tube. Stars: 3/2/1 based on moves vs. par.

**Juice tuning (what was tuned and why):**
- Pour = tube tilt toward destination + 3 staggered liquid blobs along a curved path + splash particles + "glug" + landing pop + haptic. The tilt sells the *cause*; the staggered blobs read as a *stream* rather than a teleport.
- Tube completion = star burst (additive gold/white particles) + scale pop + ascending chime arpeggio + success haptic. Completion must feel like a *reward*, not just a state change.
- Level win = full-screen confetti rain (candy color sequence, gravity) + fanfare + delayed overlay so the celebration lands before UI appears.
- Illegal move = quick horizontal shake + dull error buzz. Fast (0.32s) so it never feels punishing.
- Selected tube lifts 16pt with a soft glow — the affordance for "this is the source".
- All sounds are synthesized at runtime (no assets to ship); all textures are procedural.

## Roadmap

- **M2:** themes (tube/liquid visual packs), daily challenge + streaks
- **M3:** boosters (extra tube, undo refill), AdMob rewarded/interstitial, IAP (remove ads, booster packs)
- **M4:** App Store Connect setup (IAP products, age rating, privacy labels), TestFlight, review, ship

## Apple review posture

No sign-in, no external billing or web links, fully playable offline, zero data collection (privacy manifest declares `NSPrivacyTracking: false`, no data types), every on-screen button works. Portrait iPhone only.
