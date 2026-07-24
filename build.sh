#!/bin/bash
set -e

APP_NAME="BBar"
APP_BUNDLE="${APP_NAME}.app"

echo "Building ${APP_NAME} using Swift compiler..."
swift build -c release

echo "Creating application bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

if [ -f "icon.png" ]; then
    echo "Creating app iconset..."
    mkdir -p AppIcon.iconset
    sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png
    sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png
    sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png
    sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png
    sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png
    sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png
    sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png
    sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png
    sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png
    sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png
    
    echo "Compiling icns file..."
    iconutil -c icns AppIcon.iconset
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    rm -rf AppIcon.iconset AppIcon.icns
fi

echo "Copying binary and Info.plist..."
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "Applying ad-hoc code signature..."
codesign --force --sign - "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Making executable..."
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Successfully built ${APP_BUNDLE}!"
