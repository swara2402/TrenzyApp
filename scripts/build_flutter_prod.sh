#!/bin/bash
# ==============================================================================
# Trenzy Production Build Script for Client (Flutter)
# ==============================================================================
# Usage:
#   ./scripts/build_flutter_prod.sh android <STAGING_API_BASE_URL>
#   ./scripts/build_flutter_prod.sh [web|macos] <API_BASE_URL>
# ==============================================================================

set -e

PLATFORM="${1:-}"
API_URL="${2:-}"

echo "=================================================="
echo " Building Trenzy Production Client for: $PLATFORM"
echo " Backend API Base URL: $API_URL"
echo "=================================================="

if [ -z "$API_URL" ] || [[ ! "$API_URL" =~ ^https://[^[:space:]]+$ ]] || [[ "$API_URL" == *"<"* ]] || [[ "$API_URL" == *">"* ]]; then
    echo "Error: provide a real HTTPS API base URL (no placeholder host)."
    echo "Usage: ./scripts/build_flutter_prod.sh android https://staging.your-domain.example"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required to verify staging backend readiness."
    exit 1
fi

echo "Checking backend readiness..."
HEALTH_RESPONSE="$(curl --fail --silent --show-error --connect-timeout 5 --max-time 15 "${API_URL%/}/api/health/ready")" || {
    echo "Error: staging backend readiness request failed."
    exit 1
}
if ! grep -Eq '"status"[[:space:]]*:[[:space:]]*"ready"' <<<"$HEALTH_RESPONSE"; then
    echo "Error: staging backend did not report ready."
    echo "$HEALTH_RESPONSE"
    exit 1
fi

case "$PLATFORM" in
    android)
        if [ ! -s android/app/google-services.json ]; then
            echo "Error: android/app/google-services.json is required for Android Firebase/Google sign-in."
            exit 1
        fi
        echo "Building signed Android release APK..."
        flutter build apk --release \
            --dart-define=TRENZY_API_BASE_URL="$API_URL" \
            --dart-define=TRENZY_USE_MOCK_API=false \
            --dart-define=FF_DEV_AUTH_BYPASS=false
        echo "APK built at: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    web)
        echo "📦 Building Flutter Web release bundle..."
        flutter build web --release \
            --dart-define=TRENZY_API_BASE_URL="$API_URL" \
            --dart-define=TRENZY_USE_MOCK_API=false \
            --dart-define=FF_DEV_AUTH_BYPASS=false \
            --web-renderer html
        echo "✅ Web build complete! Output in: build/web"
        ;;
    macos)
        echo "📦 Building Flutter macOS release app..."
        flutter build macos --release \
            --dart-define=TRENZY_API_BASE_URL="$API_URL" \
            --dart-define=TRENZY_USE_MOCK_API=false \
            --dart-define=FF_DEV_AUTH_BYPASS=false
        echo "✅ macOS build complete! Output in: build/macos/Build/Products/Release"
        ;;
    *)
        echo "Error: unknown platform '$PLATFORM'. Supported platforms: android, web, macos."
        exit 1
        ;;
esac
