# Contributing to Luxafor Monitor

Thanks for taking a look. This project is a small macOS menu bar utility
with a deliberately narrow scope — please read the "Code style" section
below before adding a dependency or a new abstraction layer.

## Architecture overview

The package is split into three modules under `Sources/`:

- **`LuxaforKit`** — talks to the Luxafor USB device over IOKit HID. It
  owns the byte-level protocol (vendor ID, report format, color/pattern
  opcodes) and exposes a small device protocol/interface for setting the
  light's color or turning it off, plus handling for the device being
  unplugged or reconnected. It has no dependency on the other two modules
  and no UI code.
- **`MeetingDetectionKit`** — determines whether the user is currently in
  a meeting, using two local signals: `AVFoundation`'s
  `isInUseByAnotherApplication` camera/mic flag, and Accessibility-API
  (`AXUIElement`) inspection of Zoom's and Teams' window titles and UI
  element labels. It contains the fusion/debounce coordinator that merges
  both signals into a single meeting-state boolean, per-app detector
  rules, and the permissions manager that requests/checks Accessibility
  and Camera/Microphone authorization. It has no dependency on
  `LuxaforKit` and no UI code.
- **`LuxaforMonitorApp`** — the SwiftUI `MenuBarExtra` app. It wires
  `MeetingDetectionKit`'s output to `LuxaforKit`'s device control, and
  owns the menu bar UI: status display, the Auto/Force Red/Force
  Green/Force Off override picker, preferences, and first-run onboarding
  (permission prompts/explanations).

Dependency direction is strictly `LuxaforMonitorApp → {LuxaforKit,
MeetingDetectionKit}`; the two lower-level modules never depend on each
other or on the app target. This keeps both independently unit-testable.

## Building and testing locally

Requires Xcode 16 / a Swift 6.3 toolchain, macOS 13+.

```sh
swift build          # debug build of everything
swift test            # run LuxaforKitTests + MeetingDetectionKitTests
swift run LuxaforMonitorApp   # run the app for manual testing
```

To build a release `.app` bundle / DMG the way CI does (useful for testing
packaging changes without waiting on CI):

```sh
Scripts/build-app.sh 0.1.0
Scripts/sign-adhoc.sh
Scripts/package-dmg.sh 0.1.0
```

See [Scripts/README](#scripts) below (i.e. the comments at the top of each
script) for details and required arguments/env vars.

## Manual QA checklist

Accessibility-based UI detection and physical hardware interaction can't
be meaningfully unit tested. Before merging a change that touches
detection, permissions, or device I/O, please walk through this checklist
by hand:

- [ ] **Accessibility permission prompt** appears on first run when the
      app needs it, the app correctly detects grant vs. denial, and
      re-checks/updates once the user grants it from System Settings
      without requiring an app restart (if that's the intended UX).
- [ ] **Camera/Microphone permission prompt** appears and is worded
      clearly; denial doesn't crash the app.
- [ ] **Real Zoom call**: starting a Zoom call flips the light red within
      the expected debounce window; ending the call flips it back within
      the expected window.
- [ ] **Real Teams call**: same, for Microsoft Teams. Call this one out
      specifically in PR descriptions — **Teams heuristics are the part
      most likely to break** as Microsoft changes their UI/button labels
      across releases, so a Teams-detection change deserves extra manual
      verification against whatever Teams version is currently installed.
- [ ] **Device unplug/replug**: unplugging the Luxafor device mid-run
      doesn't crash the app or spin the CPU; replugging it resumes normal
      light control without requiring an app restart.
- [ ] **Manual override**: each of Auto / Force Red / Force Green / Force
      Off actually drives the light correctly, and switching back to Auto
      re-syncs to the current detected state.
- [ ] **Launch at Login**: toggling it on/off actually adds/removes the
      login item, and it survives a reboot.

## Testing without physical Luxafor hardware

`LuxaforKit` should expose its device I/O behind a small protocol (e.g.
`LuxaforDevice`) so that higher-level logic (`LuxaforMonitorApp`'s
coordinator, and any unit tests) can depend on the protocol rather than
the concrete IOKit-backed implementation. For unit tests, implement a
mock/fake conforming to that protocol that records the calls it receives
(set color, turn off, etc.) instead of touching real hardware — this lets
`MeetingDetectionKit → light` wiring be tested without a Luxafor device
plugged in. Only the concrete IOKit implementation itself needs a real
device to validate (covered by the manual QA checklist above).

## Code style

- **No third-party dependencies without discussion.** This project
  intentionally has zero third-party runtime dependencies — partly for
  simplicity, and partly because releases are ad-hoc signed rather than
  notarized, so keeping the supply chain minimal matters more than usual
  here. If you think a dependency is warranted, open an issue/discussion
  first rather than sending a PR that adds one.
- **License headers**: keep it light. A one-line SPDX identifier at the
  top of new source files is sufficient:
  ```swift
  // SPDX-License-Identifier: Apache-2.0
  ```
  Verbose license header blocks are not required or expected.
- Prefer small, focused, protocol-based abstractions (see `LuxaforDevice`
  above) over large concrete types, so both hardware I/O and Accessibility
  inspection stay mockable in tests.

## Scripts

The `Scripts/` directory holds the packaging pipeline used by
`.github/workflows/release.yml`, and each script is also meant to be run
by hand:

- `build-app.sh` — assembles `LuxaforMonitor.app` from the SwiftPM release
  binary plus `Info.plist.template`.
- `sign-adhoc.sh` — ad-hoc code-signs the `.app` (no Developer ID needed).
- `package-dmg.sh` — packages the signed `.app` into a `.dmg`.
- `sigstore-sign.sh` — signs the `.dmg` with cosign via GitHub Actions'
  keyless OIDC flow (or a locally configured cosign identity).

Run any of them with no arguments to see usage.
