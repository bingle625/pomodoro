# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Korean-language macOS menu-bar Pomodoro app (focus/break timer with per-task focus records, memos, and statistics). Swift Package Manager project; UI is AppKit windows hosting SwiftUI views. User-facing strings are Korean.

## Commands

```sh
swift test                              # run all tests (PomodoroCoreTests)
swift test --filter TimerEngineTests    # single test class
swift build -c release                  # compile release binary
bash scripts/build-app.sh               # build + assemble dist/Pomodoro.app (ad-hoc signed)
bash scripts/build-release.sh           # build .app, DMG, and signed Sparkle appcast for a new version
```

Requires macOS 14+, Swift 5.9+ toolchain. Verified on Apple Silicon. SwiftPM auto-downloads Sparkle 2.10.0 (pinned).

Tests run against `PomodoroCore` only — the app layer (`PomodoroApp`) has no test target. Set `POMODORO_DATA_PATH` to an isolated file when running the app manually so dev runs don't touch real user data at `~/Library/Application Support/Pomodoro/state.json`.

## Architecture

Two targets: `PomodoroCore` (library, all testable logic, no AppKit) and `PomodoroApp` (executable, AppKit/SwiftUI shell).

### State flow — the central invariant

All app state lives in one `AppSnapshot` (tasks, selected task, preferences, timer, records, pending-memo IDs). `AppStore` (`@MainActor @Observable`) is the single owner. **Every mutation goes through `AppStore` and is persisted before `snapshot` updates** — see `commit(_:)`: it calls `repository.save(next)` *first*, then assigns `snapshot = next`. If the save throws, the attempted snapshot is stashed in `pending` and surfaced as `storageError`; the in-memory `snapshot` stays on the last-saved value. So the on-disk file and `snapshot` never diverge.

- `ensureWritable()` gates every mutation: blocks when read-only (unreadable file), update-installing, or a save is pending. A pending save must be cleared via `retrySave()` before new edits.
- `editTimer(_:)` is the funnel for timer transitions — it ticks the clock, applies a `TimerEngine` mutation, appends a `FocusRecord` + pending memo on focus completion, and commits (ringing the bell on completion).
- `LocalRepository` writes atomically (`.atomic`) with pretty/sorted JSON and runs `validate(_:)` on both load and save. A corrupt/unsupported file is *never* overwritten — load throws, `isReadOnly` goes true, and the error (with path) is shown. `schemaVersion` is 1; `Preferences`/`TimerState` have custom `init(from:)` with `decodeIfPresent` fallbacks for forward/back-compat of newer fields.

### TimerEngine — pure timer logic

`TimerEngine` (value type over `TimerState`) holds no clock; callers pass `at now:`. Running state is deadline-based (`remaining(at:)` derives from `deadline`), so the timer is correct across pause/resume/sleep without a running loop. Phase cycle: `focus → rest`, but every `longBreakInterval`-th completed focus goes to `longRest` and resets `completedFocusCount`. `stop` resets the cycle and saves a partial "중단" record if ≥1s elapsed. `completedFocusCount` persists across pause/resume/sleep/auto-transition but resets on explicit stop or normal termination.

### ExamEngine — sequential multi-section timer (시험 모드)

`ExamEngine` (value type over `ExamTimerState`, in `PomodoroCore`, tested) is a second, independent timer for timed exams: an ordered list of named sections each with its own minute limit (e.g. HMAT 언어이해 20분 → 논리판단 10분 → …), run back-to-back with auto-advance and a bell at every boundary, resetting to `.ready` after the last. Deadline-based like `TimerEngine`; late ticks chain from the elapsed deadline. **Produces no `FocusRecord`s and is not in statistics** — it is purely a countdown. Saved sets live in `AppSnapshot.examPresets` (`ExamPreset`), the live run in `AppSnapshot.examTimer`. `AppStore.tick()` advances both timers; `startExam` requires both the pomodoro and exam timers to be `.ready`. A running exam also blocks update installation (`UpdateSafety.examActive`) and freezes on sleep. Fresh installs seed `ExamPreset.hmatSample`; the 시험 tab in `MainView` (`Exam/ExamView.swift`, `Exam/ExamPresetEditor.swift`) edits presets and drives a run.

### App shell

`AppDelegate` wires everything at launch: builds `AppStore` → `UpdateCoordinator` → `WindowCoordinator`, installs the menu, and runs a 0.2s `Timer` that calls `store.tick()` + synchronizes windows/menu-bar/updates. It also bridges macOS lifecycle: `willSleep` → `store.pauseForSleep()` (saves synchronously, freezes the timer); `applicationShouldTerminate` → `store.prepareForTermination()` (retries pending save, stops timer, cancels if save fails).

- `WindowCoordinator` owns all `NSWindow`/`NSPanel` instances (main, floating always-on-top panel, memo sheet, settings) and hosts SwiftUI roots. Windows are never released on close; the app survives closing the main window (`applicationShouldTerminateAfterLastWindowClosed` → false).
- `MenuBarTimer` renders the status-bar item and lets the user adjust duration by dragging the dial.
- SwiftUI views under `Sources/PomodoroApp/{Main,MenuBar,Dashboard,Review,Memo,Settings,Timer,...}` read `store.snapshot` and call `AppStore` methods; they do not mutate state directly.

### Auto-updates (Sparkle)

`UpdateCoordinator` wraps `SPUStandardUpdaterController`. The key custom behavior is `UpdateInstallGate` + `UpdateSafety` (both in `PomodoroCore`, tested): an update is downloaded automatically but installation is **deferred until it's safe** — no running timer, no pending save, no open memo/editor/dirty-settings window. When blocked, Sparkle's relaunch is postponed and a nonmodal notice explains the wait; install fires once the gate clears or on quit.

## Releasing a new version

Full procedure in `docs/automatic-updates.md`. Updates ship via Sparkle; **tagging source alone does not update users** — each release must attach a signed DMG + `appcast.xml` + `SHA256SUMS.txt`.

1. Bump **both** `CFBundleShortVersionString` and `CFBundleVersion` in `Packaging/Info.plist`.
2. `swift test`.
3. `bash scripts/build-release.sh` → produces DMG, signed `appcast.xml`, `SHA256SUMS.txt` in `dist/releases/v<version>/`. Aborts if that DMG already exists (bump the version first). Also aborts if the Keychain public key ≠ `Info.plist` `SUPublicEDKey`.
4. Commit source, push to `main`, create a GitHub release on that commit, attach all three artifacts, then publish.

- Feed URL (fixed): `https://github.com/bingle625/pomodoro/releases/latest/download/appcast.xml`. If the `latest` release has no appcast, update checks fail.
- Signing: Ed25519 update key lives in the dev Mac's login Keychain under Sparkle account `local.pomodoro.app` (public key only in Info.plist). Never commit/log the private key. Signing is done on this Mac, not CI. Sparkle release tools are at `.build/artifacts/sparkle/Sparkle/bin/`.
- This is Sparkle update signing, **separate** from Apple Developer ID / notarization. The `.app` ships ad-hoc signed, so first launch on another Mac may be gated by macOS security policy.

## Conventions

- Keep timer/record/persistence/update-gating logic in `PomodoroCore` with tests; `PomodoroApp` is thin glue. New rules go in the engine/store, not in views or `AppDelegate`.
- All validation bounds live in `LocalRepository.validate` and `AppStore` (focus/break/longBreak 1–60 min, longBreakInterval 1–12, total session ≤ 3600s in `updatePreferences`; exam sections 1–180 min, ≤ 20 per set in `validatedSections`). Changing a limit means updating both.
- `AppSnapshot` stays `schemaVersion` 1; new top-level fields get `decodeIfPresent` fallbacks in its custom `init(from:)` so older state files still load (same pattern as `Preferences`/`TimerState`).
- User-facing strings are Korean. Match surrounding tone.
