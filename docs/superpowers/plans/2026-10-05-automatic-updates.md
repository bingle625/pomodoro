# Automatic updates implementation plan

User approved adding the previously proposed automatic detection/download/install flow and publishing the result. Extend the existing app and release pipeline using Sparkle 2.10.0. This supersedes the initial no-external-dependencies constraint for the updater only.

## Contract

- v1.1.0 / build2, Apple Silicon, macOS14+.
- HTTPS feed at https://github.com/bingle625/pomodoro/releases/latest/download/appcast.xml; DMG and signed appcast hosted together on GitHub Releases.
- Ed25519 update and feed verification; private key stays in the login Keychain under account local.pomodoro.app. Only public key is committed.
- Automatic checking and downloading enabled by default, editable separately in settings. Manual Check for Updates in menu/settings.
- Installation/relaunch waits until timer is ready, storage healthy, no memo queue and no memo/settings/task editor is open. The same gate protects manually requested relaunch. Explicit user quit can install already downloaded update after existing saved session is preserved.
- v1.0.0 has no updater and needs one manual installation of v1.1.0. Future releases use the signed feed workflow.

## Tasks

- [x] Test installation gate first: running/paused, pending save, read-only, pending memo and open editor block; safe state executes exactly once; canceled cycle clears callback.
- [x] Add pinned Sparkle dependency, observable update controller and delegate, settings and menu integration, app termination/state handling.
- [x] Add keychain public key and feed configuration, framework embedding/signing, version bump, reproducible DMG and signed appcast packaging scripts.
- [x] Validate Core tests, release build, bundle/library signatures and resource locations, cryptographic signature verification and unsigned/tampered rejection, appcast parsing, safe migration of existing records.
- [x] Independent review, document verification limits, commit/push main, publish v1.1.0 with DMG and signed appcast, verify remote asset digests and stable feed URL.

No private key is exported or added to GitHub Secrets. Release signing remains a local command using Keychain. Developer ID/notarization remains outside current credentials. Do not interrupt the user's running app during verification.

검증 제한: 실제 GUI와 미래 버전 교체·재실행은 권한/환경 제약으로 미검증이며 docs/verification.md에 명시한다. 소스·서명·번들·정책 테스트와 원격 릴리스 파일 검증으로 전달한다.
