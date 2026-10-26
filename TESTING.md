# Device acceptance checklist

Use two or more physical iPhones running iOS 16 or later, built from the same commit. Include an iOS 16 device and a newer iOS version when checking compatibility. This checklist covers behavior that the simulator suite cannot establish.

## Solo and media

- Run in Airplane Mode with Wi-Fi off. Complete a tour; every clip should load without a download.
- Confirm all four answers fit on an iPhone SE-sized landscape screen and a large iPhone, with no clipped controls. Inspect Home, lobby, rounds and the results podium.
- Pick a wrong answer and verify zero points. Let a round expire and verify zero points. Try tapping twice: only the first answer should count.
- Pause mid-round, wait, then resume. The timer should preserve the unused time. Leave the app and return during unpaused solo play; it should resume automatically. Manually pause first, then switch apps and return: it must remain paused until you tap **Keep exploring**.
- Change name, avatar, round count, duration and collection. Relaunch; preferences and best score should persist.
- Use Reduce Motion, VoiceOver, larger text, the silent switch and disabled haptics to check essential controls and readability.

## Nearby party

1. Enable Wi-Fi and Bluetooth and use the same Wi-Fi network. On device A, host a party. Allow Local Network access.
2. On device B, browse parties, grant access, choose A. Both screens should show both chosen names and avatars. A cannot start alone.
3. Start on A. Both devices should receive the same location, four choices, order and countdown.
4. Answer on B first. B’s choice should lock. Neither device should disclose the correct answer until A answers or time expires.
5. Answer on A. Both devices should reveal the same location, each player’s correct/wrong status and the same total scores.
6. Repeat with a timeout, wrong answers and taps at the deadline. Late or duplicate packets must not add points.
7. After each reveal, both devices should show an 8-second countdown and automatically move to the same next destination without a host tap. Confirm this after both all-player answers and timeouts. After the last reveal, both should automatically show results. Compare both leaderboards. Replay: scores reset and both players remain present.
8. Disconnect B mid-round. A should mark B offline and continue without waiting for B indefinitely. B should return Home with a connection message once the transport detects departure.
9. Background B during a round. B leaves the game. Background or close A: the party should end for B.
10. Deny Local Network permission on a fresh installation. The browser should remain usable and explain how to open app settings. Enable permission and try again.
11. Host separate parties on A and C and ensure a guest sees and joins the chosen host. Try 8 players when devices are available; the ninth must not join.
12. Try incompatible catalog versions: reject the join with an explanation.

Tap as soon as a party countdown ends on a guest. If the guest's clock estimate is slightly ahead, the host must unlock an early rejected tap so the guest can retry. A late retry notification must never unlock an already accepted answer or a different round. Update every device to this protocol version; older builds are excluded from discovery.

Network notes: clock probes align the displayed countdown to the host, and the host timestamps incoming guesses. Scores intentionally include local network travel time. This is a casual nearby game; there is no remote matchmaking, reconnection into an active round, host migration or anti-cheat service.
