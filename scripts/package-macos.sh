#!/bin/bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$repo_dir/build"
xcode_developer_dir="/Applications/Xcode.app/Contents/Developer"

if [[ -z "${DEVELOPER_DIR:-}" && -x "$xcode_developer_dir/usr/bin/xcodebuild" ]] &&
    ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR="$xcode_developer_dir"
fi

/usr/bin/xcodebuild \
    -project "$repo_dir/Refract.xcodeproj" \
    -scheme Refract \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$build_dir" \
    ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' build

app="$build_dir/Build/Products/Release/Refract.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
/usr/bin/xcrun lipo "$app/Contents/MacOS/Refract" -verify_arch arm64
/usr/bin/xcrun lipo "$app/Contents/MacOS/Refract" -verify_arch x86_64

archive_name="Refract-$version-macOS.zip"
archive_dir="$(mktemp -d "$build_dir/refract-release.XXXXXX")"
trap 'rm -rf -- "$archive_dir"' EXIT
/usr/bin/ditto -c -k --norsrc --keepParent "$app" "$archive_dir/$archive_name"
/usr/bin/unzip -q "$archive_dir/$archive_name" -d "$archive_dir"
/usr/bin/codesign --verify --strict --all-architectures "$archive_dir/Refract.app"
(
    cd "$archive_dir"
    /usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256"
)
/bin/mv -f "$archive_dir/$archive_name" "$archive_dir/$archive_name.sha256" "$build_dir/"
printf '\nCreated %s\nCreated %s\n' "$build_dir/$archive_name" "$build_dir/$archive_name.sha256"
