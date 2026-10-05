#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/Pomodoro.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Pomodoro" "$app_dir/Contents/MacOS/Pomodoro"
cp Packaging/Info.plist "$app_dir/Contents/Info.plist"
# SwiftPM locates bundles next to the executable or under Bundle.main.resourceURL.
for resource in "$binary_dir"/*.bundle; do
    if [[ -d "$resource" ]]; then
        ditto "$resource" "$app_dir/Contents/Resources/$(basename "$resource")"
        ditto "$resource" "$app_dir/Contents/MacOS/$(basename "$resource")"
    fi
done
codesign --force --deep --sign - "$app_dir"
printf '%s\n' "$app_dir"
