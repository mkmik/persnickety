#!/usr/bin/env bash
# Build persnickety.app. SwiftPM can't emit .app bundles, so we assemble one.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=dist/persnickety.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/persnickety "$APP/Contents/MacOS/persnickety"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>persnickety</string>
	<key>CFBundleIdentifier</key>
	<string>com.mmikulicic.persnickety</string>
	<key>CFBundleExecutable</key>
	<string>persnickety</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<!-- Being the default browser also makes us the handler for HTML documents:
	     VPN clients (GlobalProtect) write the SAML POST form to a temp .html and
	     open it as a file. Without this, LaunchServices refuses with "persnickety
	     cannot open files in the HTML text format." -->
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>HTML document</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.html</string>
			</array>
		</dict>
	</array>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>Web site URL</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>http</string>
				<string>https</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built $APP"
