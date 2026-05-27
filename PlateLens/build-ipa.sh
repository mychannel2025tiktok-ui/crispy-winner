#!/bin/bash

# PlateLens IPA Build Script for macOS
# This script archives and exports the PlateLens app as an IPA file

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME="PlateLens"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/PlateLens.xcarchive"
EXPORT_PATH="$BUILD_DIR/ipa"

echo "🔨 Building PlateLens IPA..."
echo "Project directory: $PROJECT_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive the app
echo "📦 Creating archive..."
xcodebuild \
  -project "$PROJECT_DIR/PlateLens.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  archive

# Export the IPA
echo "📤 Exporting IPA..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$PROJECT_DIR/exportOptions.plist" \
  -exportPath "$EXPORT_PATH"

echo "✅ Build complete!"
echo "IPA file location: $EXPORT_PATH/PlateLens.ipa"
