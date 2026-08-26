# PostureFix Roadmap

A macOS menu bar app that watches your posture via webcam (Vision framework pose/face landmarks) and nudges you when you slouch — built feature-by-feature to match the Dorso-style posture app experience.

Stack: Swift + SwiftUI (macOS 13+), AVFoundation (camera capture), Vision (face/pose landmark detection), UserNotifications (alerts), menu bar (`MenuBarExtra`).

## Phases

1. **Project scaffold** — Swift Package executable app, macOS App lifecycle, menu bar icon shell, camera permission (Info.plist), app runs and shows in menu bar.
2. **Camera capture pipeline** — AVCaptureSession wired to a Vision request handler, live frame processing loop, camera on/off toggle.
3. **Posture detection** — Vision face-landmarks (nose/eye/ear angle + vertical head position) to compute a live "posture score"; fallback to face bounding-box size/position as a slouch proxy.
4. **Calibration** — "Set my good posture" flow that captures a baseline pose, stores it, and defines the deviation threshold for "slouching."
5. **Real-time alerts** — When slouch is sustained past a grace period: menu bar icon changes state, macOS notification fires, optional sound.
6. **Session tracking** — Track time in good vs. bad posture per session, persist locally (SwiftData/UserDefaults).
7. **Stats dashboard** — Popover UI: today's good-posture %, slouch count, trend over the week.
8. **Streaks & history** — Daily streak counter, calendar/history view of past days' scores.
9. **Settings** — Sensitivity slider, alert frequency/snooze, launch-at-login, camera privacy toggle.
10. **Onboarding** — First-run flow: camera permission request, calibration step, brief walkthrough.
11. **Polish** — Menu bar icon states/animations, app icon, empty states, error handling for denied camera access.

## Working agreement

Each phase ships as working, run-tested code before moving to the next. I'll build phases in order unless you want to reprioritize or skip something.
