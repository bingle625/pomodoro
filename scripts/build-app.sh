#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/Pomodoro.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Frameworks"
cp "$binary_dir/Pomodoro" "$app_dir/Contents/MacOS/Pomodoro"
cp Packaging/Info.plist "$app_dir/Contents/Info.plist"
cp Packaging/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
# SwiftPM locates bundles next to the executable or under Bundle.main.resourceURL.
for resource in "$binary_dir"/*.bundle; do
    if [[ -d "$resource" ]]; then
        ditto "$resource" "$app_dir/Contents/Resources/$(basename "$resource")"
        ditto "$resource" "$app_dir/Contents/MacOS/$(basename "$resource")"
    fi
done
sparkle_framework="$binary_dir/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
    sparkle_framework="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
fi
[[ -d "$sparkle_framework" ]] || { echo "Sparkle.framework not found" >&2; exit 1; }
ditto "$sparkle_framework" "$app_dir/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$app_dir/Contents/Resources/Sparkle-LICENSE.txt"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
printf '%s\n' "$app_dir"
