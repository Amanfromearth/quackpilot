#!/usr/bin/env bash
#
# Build Quackpilot.app from the SPM target.
#
# Usage:
#   ./build.sh           # release build, package into Quackpilot.app
#   ./build.sh --open    # ...then open the app
#
# The first time you open the resulting .app, macOS will complain about an
# unidentified developer. Right-click → Open (or run: xattr -d com.apple.quarantine Quackpilot.app).

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Quackpilot"
BUNDLE_ID="com.anurag.quackpilot"
APP_DIR="${APP_NAME}.app"
RELEASE_DIR=".build/release"

echo "→ swift build -c release"
swift build -c release

echo "→ packaging ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Executable
cp "${RELEASE_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# SPM places resource bundles next to the binary as ${PackageName}_${TargetName}.bundle.
# Bundle.module locates them by walking from the executable, so we put it in MacOS/.
if [ -d "${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${APP_DIR}/Contents/MacOS/"
fi

# Info.plist — LSUIElement hides the Dock icon (menu-bar-only agent app).
cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc codesign so SMAppService can identify the bundle for login-item registration.
# Without this, "Launch at login" silently fails because LaunchServices can't anchor the app.
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

# Strip quarantine xattr that gets added when downloaded from web.
xattr -cr "${APP_DIR}" 2>/dev/null || true

echo
echo "✓ ${APP_DIR} ready ($(du -sh "${APP_DIR}" | cut -f1))"
echo "  Launch:                open ./${APP_DIR}"
echo "  Auto-launch on boot:   open the settings panel (menu bar ✈ → Settings…) and toggle 'Launch at login'"

if [[ "${1:-}" == "--open" ]]; then
    open "./${APP_DIR}"
fi
