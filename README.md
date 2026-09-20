# Luxafor Monitor

[![CI](https://github.com/OWNER/luxafor-monitor/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/luxafor-monitor/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A tiny macOS menu bar app that watches for meetings in **Zoom** and
**Microsoft Teams** and drives a [Luxafor](https://luxafor.com) USB status
light — red when you're in a call, green when you're not — so people
walking by (or in the next room) know not to interrupt you. A manual
override is always one click away in the menu bar.

Luxafor Monitor is Apache-2.0 licensed, has **zero third-party runtime
dependencies**, sends **no telemetry**, and talks to **no cloud service of
any kind**. Everything it does happens locally on your Mac.

> **Naming note:** "Luxafor Monitor" is an independent, community project.
> It is not affiliated with, endorsed by, or sponsored by Luxafor, Zoom, or
> Microsoft. All trademarks belong to their respective owners.

---

## Table of contents

- [What it does](#what-it-does)
- [Supported meeting apps](#supported-meeting-apps)
- [Why these permissions?](#why-these-permissions)
- [How detection works](#how-detection-works)
- [Manual override](#manual-override)
- [Installing a release](#installing-a-release)
- [Building from source](#building-from-source)
- [Extending to a new meeting app](#extending-to-a-new-meeting-app)
- [Contributing](#contributing)
- [License](#license)

## What it does

Luxafor Monitor sits quietly in your menu bar. When it detects you're in a
Zoom or Teams meeting, it turns your Luxafor USB light red. When the
meeting ends, it turns the light green (or off, depending on your
preference). No dashboards, no accounts, no configuration servers — just a
light that reflects your call state.

## Supported meeting apps

- **Zoom** (desktop client)
- **Microsoft Teams** (desktop client)

The detection layer is intentionally pluggable — see
[Extending to a new meeting app](#extending-to-a-new-meeting-app) — so
support for other conferencing apps (Google Meet, Webex, FaceTime, etc.)
can be added without touching the core coordinator or the USB light logic.

## Why these permissions?

Luxafor Monitor has no access to the Zoom or Microsoft Graph APIs — it
never authenticates as you, never talks to Zoom's or Microsoft's servers,
and never sees your meeting content, calendar, chat, or participant list.
Instead, it infers "you're probably in a meeting" purely from **local,
unauthenticated signals that macOS already exposes to any app**. That
requires two permission grants, and we want to be upfront about exactly
what each one is for:

- **Accessibility.** Luxafor Monitor uses the macOS Accessibility API
  (`AXUIElement`) to read the *window titles* and some *UI element labels*
  of the Zoom and Teams applications specifically — for example, Zoom's
  active call window is reliably titled "Zoom Meeting". Teams has no
  single stable marker, so its detector uses heuristic matching against
  known button labels (e.g. "Leave", "Hang up") that appear during a live
  call. This permission lets the app *read UI metadata from other apps'
  windows*; it does not let the app control your Mac, log your keystrokes,
  or read the content of documents, browsers, or any app other than Zoom
  and Teams (the code only inspects those two bundle identifiers).
- **Camera and Microphone.** Luxafor Monitor checks
  `AVCaptureDevice.isInUseByAnotherApplication`, a coarse, system-wide flag
  that tells an app whether *some* process is currently using the camera
  or microphone — without revealing which process, or any audio/video
  data. macOS only exposes this flag to apps that have been granted
  camera/microphone permission themselves, even though Luxafor Monitor
  never opens a capture session, never records, and never transmits audio
  or video. This signal is a coarse fallback/corroboration signal used
  alongside the Accessibility-based window detection, not the primary
  source of truth.

Both permissions are requested only when needed, both can be revoked at
any time in **System Settings → Privacy & Security**, and revoking either
one simply degrades detection accuracy — it does not crash the app.

## How detection works

At a high level, for each supported app Luxafor Monitor combines:

1. **Media-in-use signal** — is the camera or microphone currently in use
   by another application? (coarse, system-wide, app-agnostic)
2. **Window/UI inspection** — does Zoom or Teams currently have a window
   or UI element present that's characteristic of an active call?

These two signals are fused and debounced (to avoid flapping the light on
brief camera/mic blips, or on windows that appear and disappear quickly)
by a small coordinator in `MeetingDetectionKit`. The result is a simple
in-a-meeting / not-in-a-meeting boolean that drives the Luxafor light via
`LuxaforKit`.

There is no cloud component. There is no telemetry, analytics, or crash
reporting phoning home. There is no background network access at all in
normal operation — the only network activity in this project is GitHub
Actions building and signing releases.

## Manual override

The menu bar dropdown always shows four modes:

| Mode | Behavior |
|---|---|
| **Auto** | Light follows detected meeting state (the default). |
| **Force Red** | Light stays red regardless of detected state. |
| **Force Green** | Light stays green regardless of detected state. |
| **Force Off** | Light is turned off and left alone. |

Switching back to **Auto** immediately re-syncs the light to whatever the
detector currently believes your meeting state is.

## Installing a release

1. Download the latest `.dmg` from the
   [Releases](../../releases) page.
2. Open the DMG and drag **LuxaforMonitor.app** to `/Applications`.
3. **The app is not notarized by Apple** (see below), so on first launch
   macOS Gatekeeper will refuse to open it with an "unidentified
   developer" warning. To run it anyway:
   - **Right-click (or Control-click) the app → Open → Open**, or
   - Remove the quarantine flag from Terminal:
     ```sh
     xattr -d com.apple.quarantine /Applications/LuxaforMonitor.app
     ```
4. Grant Accessibility and Camera/Microphone permission when prompted (see
   [Why these permissions?](#why-these-permissions)).

### Why isn't it notarized?

Apple notarization requires an active **Apple Developer ID membership,
which costs $99/year**. This is a free, volunteer open-source project
without that budget, so releases are **ad-hoc signed** only
(`codesign --sign -`), which satisfies the minimum macOS requirement to
run a downloaded binary at all but does *not* satisfy Gatekeeper's
notarization check. This is expected and not a bug.

### Verifying a release hasn't been tampered with

Since releases aren't notarized, we instead sign each release artifact
with **[Sigstore](https://www.sigstore.dev/) / cosign**, using GitHub
Actions' free keyless OIDC signing — no private keys or secrets are held
by the maintainers. This proves the DMG was built by this repository's CI
from the tagged source and hasn't been modified since, though — to be
clear — **it is a supply-chain integrity check, not a Gatekeeper
substitute**; it doesn't remove the "unidentified developer" warning.

Each release includes the DMG plus a `.sig`/certificate bundle and a
`SHA256SUMS` file. To verify, once `cosign` is installed
(`brew install cosign`):

```sh
cosign verify-blob \
  --certificate LuxaforMonitor-<version>.dmg.pem \
  --signature   LuxaforMonitor-<version>.dmg.sig \
  --certificate-identity-regexp "https://github.com/OWNER/luxafor-monitor/.github/workflows/release.yml@.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  LuxaforMonitor-<version>.dmg
```

and/or check the plain checksum:

```sh
shasum -a 256 -c SHA256SUMS
```

## Building from source

Requires Xcode 16 / a Swift 6.3 toolchain and macOS 13+.

```sh
git clone https://github.com/OWNER/luxafor-monitor.git
cd luxafor-monitor
swift build
swift test
```

To run the app during development:

```sh
swift run LuxaforMonitorApp
```

To produce a release `.app` bundle and DMG locally the same way CI does,
see the scripts in [`Scripts/`](Scripts/) and
[CONTRIBUTING.md](CONTRIBUTING.md).

## Extending to a new meeting app

The Accessibility-based detector is designed around small, declarative
rules rather than one-off code per app, so adding a new conferencing app
is usually one of two things:

1. **Preferred: a declarative rule**, if the target app has a
   recognizable window title or a small set of stable button/element
   labels that only appear during an active call (the way Zoom's window
   is titled "Zoom Meeting", or Teams shows a "Leave" button). Add a rule
   describing the app's bundle identifier and the title/label patterns
   that indicate "in a call" to the Accessibility detector in
   `MeetingDetectionKit`, alongside the existing Zoom/Teams rules.
2. **Fallback: a small custom detector**, if the app's UI doesn't fit the
   declarative pattern (e.g. it needs to look at multiple windows, or
   combine several conditions). Implement the same detector
   protocol/interface the Zoom and Teams detectors implement, and register
   it with the fusion/debounce coordinator alongside the others.

In both cases, the media-in-use (camera/mic) signal is shared
infrastructure and doesn't need to be reimplemented per app — only the
window/UI-specific part does. See `MeetingDetectionKit`'s source and
`CONTRIBUTING.md`'s manual QA checklist for what to verify by hand before
opening a PR (Accessibility-based detection is inherently hard to fully
unit test).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture notes, local dev
setup, the manual QA checklist, and code style expectations.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
