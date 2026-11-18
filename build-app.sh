#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PROJECT_DIR"

APP_COMMIT="${APP_COMMIT:-}"
if [ -z "$APP_COMMIT" ]; then
    APP_COMMIT=$(git rev-parse --short=7 HEAD 2>/dev/null || true)
fi
APP_COMMIT="${APP_COMMIT:-none}"

APP_VERSION="${APP_VERSION:-}"
if [ -z "$APP_VERSION" ]; then
    if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
        APP_VERSION="${GITHUB_REF_NAME:-}"
    else
        APP_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || true)
    fi
fi
APP_VERSION="${APP_VERSION#v}"
APP_VERSION="${APP_VERSION:-0.1.0}"
if ! printf '%s\n' "$APP_VERSION" | grep -Eq '^[0-9]+(\.[0-9]+){2}$'; then
    printf 'Invalid app version: %s (expected X.Y.Z)\n' "$APP_VERSION" >&2
    exit 1
fi

swift build -c release

APP_BUNDLE="$PROJECT_DIR/.build/Mumutte.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$PROJECT_DIR/.build/release/Mumutte" "$APP_BUNDLE/Contents/MacOS/Mumutte"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MumutteCommit $APP_COMMIT" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
printf 'Created %s\n' "$APP_BUNDLE"
printf 'Open it with: open "%s"\n' "$APP_BUNDLE"
