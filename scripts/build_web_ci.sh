#!/bin/bash
# ============================================================
# SmartAttend — Web Build Script for Vercel / Netlify / Render
# Clones Flutter SDK if not installed, builds web output.
# ============================================================

set -e

if ! command -v flutter &> /dev/null; then
    echo "⚡ Flutter not found in PATH. Installing Flutter SDK (stable)..."
    if [ ! -d "flutter" ]; then
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
    fi
    export PATH="$PATH:$PWD/flutter/bin"
fi

echo "🚀 Running Flutter doctor..."
flutter --version

echo "📦 Fetching dependencies..."
flutter pub get

echo "🏗️ Building Flutter Web release..."
flutter build web --release --no-tree-shake-icons

echo "✅ Web build completed successfully! Output in build/web"
