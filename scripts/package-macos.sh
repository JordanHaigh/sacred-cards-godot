#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
if [ "$(uname -s)" != Darwin ]; then
    echo "This bundle script requires macOS." >&2
    exit 1
fi
build_profile=release
if [ "${1:-}" = --debug ]; then
    build_profile=debug
    ./scripts/cargo.sh build --bin sacred-cards --offline
else
    ./scripts/cargo.sh build --release --bin sacred-cards --offline
fi
bundle_path="$project_dir/dist/Sacred Cards.app"
mkdir -p "$bundle_path/Contents/MacOS" "$bundle_path/Contents/Resources"
cp "target/$build_profile/sacred-cards" "$bundle_path/Contents/MacOS/sacred-cards"
ln -sfn "$project_dir/sacred-cards-decompiled/build/assets" "$bundle_path/Contents/Resources/assets"
cat > "$bundle_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>sacred-cards</string>
<key>CFBundleIdentifier</key><string>local.sacredcards.rust</string>
<key>CFBundleName</key><string>Sacred Cards</string>
<key>CFBundleDisplayName</key><string>Sacred Cards</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "Built $bundle_path"
echo "Assets are linked to this checkout; this is a local application bundle."
