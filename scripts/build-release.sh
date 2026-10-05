#!/bin/bash
# Build a DMG and signed Sparkle feed. The private key never leaves Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)"
architecture="$(uname -m)"
release_dir="$PWD/dist/releases/v$version"
archive="$release_dir/Pomodoro-$version-$architecture.dmg"
tools_dir="$PWD/.build/artifacts/sparkle/Sparkle/bin"
expected_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Packaging/Info.plist)"
actual_key="$("$tools_dir/generate_keys" --account local.pomodoro.app -p)"
[[ "$actual_key" == "$expected_key" ]] || { echo 'The signing key does not match the application public key.' >&2; exit 1; }
[[ ! -e "$archive" ]] || { echo "Archive already exists: $archive. Bump the version before publishing a new release." >&2; exit 1; }
mkdir -p "$release_dir"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/pomodoro-release.XXXXXX")"
ditto dist/Pomodoro.app "$stage_dir/Pomodoro.app"
ln -s /Applications "$stage_dir/Applications"
printf 'Pomodoro %s\n\nPomodoro.app을 Applications 폴더로 드래그하세요.\nApple Silicon Mac · macOS 14 이상\n\n이 앱은 Developer ID 공증을 받지 않은 로컬 서명 앱입니다.\nhttps://github.com/bingle625/pomodoro\n' "$version" > "$stage_dir/설치 안내.txt"
hdiutil create -volname "Pomodoro $version" -srcfolder "$stage_dir" -format UDZO "$archive"
hdiutil verify "$archive"
"$tools_dir/generate_appcast" --account local.pomodoro.app --maximum-deltas 0 --download-url-prefix "https://github.com/bingle625/pomodoro/releases/download/v$version/" "$release_dir"
"$tools_dir/sign_update" --account local.pomodoro.app --verify "$release_dir/appcast.xml"
(cd "$release_dir" && shasum -a 256 "Pomodoro-$version-$architecture.dmg" appcast.xml > SHA256SUMS.txt)
printf '\nRelease artifacts: %s\n' "$release_dir"
