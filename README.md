# Screensaver Trivia

A native, landscape iPhone party game. Watch a real location, choose one of four places, and earn more points for answering sooner. The interface follows SongPop Party’s landscape menu, player ribbon, large answer buttons and podium flow, with original travel artwork and location footage.

## Run on your Mac

Requires **Xcode 16 or later** and an **iPhone or iPhone Simulator running iOS 17 or later**.

```sh
git clone https://github.com/riverdevprojects/screensaver-trivia.git
cd screensaver-trivia
open ScreensaverTrivia.xcodeproj
```

1. Select the **ScreensaverTrivia** scheme and an iPhone simulator, then press **⌘R**.
2. For a physical iPhone, choose your Apple development team in the app target’s **Signing & Capabilities**, connect the phone, select it as the destination, and run. Change the bundle identifier if your account requires it.
3. Rotate the phone to landscape. All footage is included in the repository; no API keys, package installation or internet connection is needed to play.

The repository contains the complete `.xcodeproj`, shared scheme, media and assets. There is no project-generation step required to open it in Xcode.

## Play

- **Solo:** Tap **Solo** to start a five-round tour. Watch the clip and tap one answer. The reveal shows your score and response time; tap **Next destination**. Pause using the top-right button. Solo play also pauses when the app leaves the foreground. Automatic pauses resume when you return; a manual pause stays paused until you tap **Keep exploring**.
- **Party:** Install the app on 2–8 iPhones. Keep them on the same Wi-Fi with Wi-Fi and Bluetooth on, and allow **Local Network** access. On one device choose **Party → Host a party**. On the others choose **Party → Join a nearby party** and tap the host’s name. The host starts the game and advances rounds.
- **Settings:** Change your name, avatar, collection, number of rounds, time limit and haptics. The host’s collection, round count and timer apply to the party. A collection caps the round count at the number of unique locations it contains.

Each correct answer earns `floor(1000 − 900 × elapsed / duration)` points, falling from 1,000 toward 100 before the deadline. Wrong answers and timeouts earn zero. Your first answer locks in. In a party, correctness stays hidden until everyone answers or the timer expires. The host computes scores using the time answers arrive; local network latency is included. Total score decides the winner, followed by correct-answer count, then the total time of correct answers. An exact tie uses a stable player-ID order for presentation.

The six-place starter pack contains San Francisco, Paris, Sydney, Glanni Falls in Iceland, Dubai and New York City. Three collections provide different mixes. Clips are real, licensed footage, including a Sydney drone shot and city timelapses; this starter pack is not a uniform library of aerial shots. Every clip is bundled as silent H.264, so it works offline and loops during longer rounds. Attribution and license links are available under **Settings → Footage & credits** and in [MEDIA_CREDITS.md](MEDIA_CREDITS.md).

## Base version features

- SwiftUI interface, custom globe artwork, app icon, landscape layout and native video playback.
- Complete solo flow: countdown, four choices, timer, answer lock, reveal, scoring, results, replay and pause/resume.
- Real nearby multiplayer through Apple’s encrypted Multipeer Connectivity framework. The host owns the deck, clock, accepted guesses, round transitions and scores. Peers exchange clock probes for aligned countdowns; no server or account is used.
- No repeated location within a game; shuffled rounds and choices.
- Handling for stale/duplicate/late guesses, invalid choices, disconnected players and host departure. Late joins are closed during a match. Replay retains connected players and resets all scores.
- Local name, avatar, preferences, best score and game totals. No analytics or account system.
- Local-network permission text, Bonjour declaration and privacy manifest for the app’s UserDefaults use.

Keep the app open during party play. iOS may suspend nearby networking in the background, so leaving the foreground during a party exits that device; if the host exits, the party closes for everyone. After a replay lobby opens, the current players can continue together. To invite new players after a match, return Home and host a new party.

## Verification

In Xcode, press **⌘U** to run the unit and UI tests. Or run:

```sh
xcodebuild test \
  -project ScreensaverTrivia.xcodeproj \
  -scheme ScreensaverTrivia \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Choose an installed simulator name if yours differs. Tests cover scoring boundaries, shuffled choices, unique decks, invalid and duplicate guesses, ranking, message encoding, complete solo games, timeouts, pause/resume, replay and bundled media. Simulated host/guest tests verify hidden answers, authoritative scoring, stale snapshots and disconnect handling without a radio connection. UI tests exercise Home → game → reveal → results → replay, settings and the lobby, and capture screenshots. The Debug-only `--uitesting` launch argument skips round countdowns and disables actual nearby discovery for deterministic UI tests.

The [iOS build and tests workflow](.github/workflows/ios.yml) runs on a GitHub-hosted Mac for pushes to `main` and pull requests. It publishes the build log, XCTest result bundle and screenshots under the run’s **iOS-test-results** artifact. See the [Actions tab](https://github.com/riverdevprojects/screensaver-trivia/actions) for actual run results.

Two-device discovery, local-network permissions and timing should also be tested on physical iPhones; simulator tests do not validate radio networking. A device checklist is in [TESTING.md](TESTING.md).

Portable pack/project checks:

```sh
python3 scripts/validate_project.py
```

## Project structure

```text
ScreensaverTrivia/
  App/          App entry point and root navigation
  Core/         Codable models, scoring, deck building, validation and catalog
  Services/     Match state machine and nearby-device transport
  UI/           Home, lobby, game, results, settings and video surface
  Resources/    Offline media, catalog, icon, Info.plist and privacy manifest
ScreensaverTriviaTests/
ScreensaverTriviaUITests/
```

To replace or expand the starter footage, add clips and attribution to `Resources/Media` and `Resources/locations.json`. IDs must match the `.mp4` and `.jpg` filenames. Keep at least four locations in each selectable collection. Increment `GameRules.catalogVersion` when changing the pack or making incompatible wire-protocol changes so nearby devices cannot play mismatched builds. Include the new files in the resource folders; the checked-in blue folder reference picks up media automatically.

Development-only tools: `scripts/prepare_media.py` can reproduce the media adaptations from their Commons sources using Python, Pillow and imageio-ffmpeg. `scripts/generate_project.py` reproduces the Xcode project after adding Swift files. Neither is needed to build or run the checked-in app.

## App Store next steps

This is a runnable base version, not a submitted App Store release. Before distribution, verify the party checklist on real devices, finish the desired content library and accessibility/device QA, select your distribution team and final bundle ID, prepare screenshots and listing/privacy details, and archive a Release build for TestFlight in Xcode. No App Store submission or signing account is configured in this repository.

Layout reference: [SongPop Party on the App Store](https://apps.apple.com/us/app/songpop-party/id1551639567). Platform reference: [Apple Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity).
