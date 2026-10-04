#!/bin/bash
# ==============================================================================
# Trenzy Production Build Script for Client (Flutter)
# ==============================================================================
# Usage:
#   ./scripts/build_flutter_prod.sh [web|macos] <API_BASE_URL>
# Example:
#   ./scripts/build_flutter_prod.sh web https://api.trenzy.com
# ==============================================================================

set -e

PLATFORM="${1:-web}"
API_URL="${2:-https://api.trenzy.com}"

echo "=================================================="
echo " Building Trenzy Production Client for: $PLATFORM"
echo " Backend API Base URL: $API_URL"
echo "=================================================="

if [ -z "$API_URL" ]; then
    echo "❌ Error: API_BASE_URL must be provided."
    echo "Usage: ./scripts/build_flutter_prod.sh [web|macos] <API_BASE_URL>"
    exit 1
fi

case "$PLATFORM" in
    web)
        echo "📦 Building Flutter Web release bundle..."
        flutter build web --release \
            --dart-define=TRENZY_API_BASE_URL="$API_URL" \
            --dart-define=TRENZY_USE_MOCK_API=false \
            --web-renderer html
        echo "✅ Web build complete! Output in: build/web"
        ;;
    macos)
        echo "📦 Building Flutter macOS release app..."
        flutter build macos --release \
            --dart-define=TRENZY_API_BASE_URL="$API_URL" \
            --dart-define=TRENZY_USE_MOCK_API=false
        echo "✅ macOS build complete! Output in: build/macos/Build/Products/Release"
        ;;
    *)
        echo "❌ Unknown platform: $PLATFORM. Supported platforms: web, macos"
        exit 1
        ;;
esac
