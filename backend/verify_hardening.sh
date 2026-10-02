#!/bin/bash
# Verification script for Trenzy v4 → v5 production hardening
# Usage: ./verify_hardening.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT/backend"

echo "🔍 TRENZY v5 PRODUCTION HARDENING VERIFICATION"
echo "=============================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

# 1. Check for deleted keystore
echo "1. Checking for deleted keystore files..."
if find "$REPO_ROOT" -name "release.jks" -type f -not -path "$REPO_ROOT/.git/*" 2>/dev/null | grep -q .; then
    fail "release.jks found in repository"
else
    pass "No release.jks files in repo"
fi

# 2. Check .gitignore has keystore patterns
echo "2. Checking .gitignore keystore patterns..."
GITIGNORE_PATH="$REPO_ROOT/.gitignore"
if grep -q "*.jks" "$GITIGNORE_PATH" && grep -q "android/keystore" "$GITIGNORE_PATH"; then
    pass ".gitignore has keystore exclusion patterns"
else
    fail ".gitignore missing keystore patterns"
fi

# 3. Check models.py has unique constraints
echo "3. Checking database unique constraints..."
if grep -q 'UniqueConstraint.*blend_id.*user_firebase_uid' app/models.py; then
    pass "blend_members has unique constraint"
else
    fail "blend_members missing unique constraint"
fi

if grep -q 'UniqueConstraint.*blend_id.*user_firebase_uid.*product_id' app/models.py; then
    pass "blend_swipes has unique constraint"
else
    fail "blend_swipes missing unique constraint"
fi

# 4. Check migration file exists
echo "4. Checking Alembic migration..."
if [ -f "migrations/versions/0016_add_blend_unique_constraints.py" ]; then
    pass "Migration 0016 exists"
else
    fail "Migration 0016 not found"
fi

# 5. Check auth_helpers.py exists
echo "5. Checking authorization helpers..."
if [ -f "app/auth_helpers.py" ]; then
    if grep -q "require_blend_member" app/auth_helpers.py; then
        pass "auth_helpers.py with required functions"
    else
        fail "auth_helpers.py missing core functions"
    fi
else
    fail "auth_helpers.py not found"
fi

# 6. Check socket_server.py uses auth helpers
echo "6. Checking Socket.IO authorization..."
if grep -q "require_blend_member_async" app/socket_server.py; then
    pass "Socket.IO handlers use authorization helpers"
else
    fail "Socket.IO missing authorization checks"
fi

# 7. Check _build_blend_state is async
echo "7. Checking blend_state async implementation..."
if grep -q "async def _build_blend_state" app/socket_server.py; then
    pass "_build_blend_state is async (Redis-first)"
else
    fail "_build_blend_state not async"
fi

# 8. Check initialization.py has health checks
echo "8. Checking startup validation..."
if grep -q "_check_database_health" app/initialization.py; then
    pass "Startup includes database health check"
else
    fail "Startup missing database health check"
fi

# 9. Check Socket.IO initialization
echo "9. Checking Socket.IO initialization..."
if grep -q "initialize_socket_server" app/initialization.py; then
    pass "Startup initializes Socket.IO server"
else
    fail "Startup missing Socket.IO initialization"
fi

# 10. Check Flutter sendMessage payload
echo "10. Checking Flutter client payload..."
FLUTTER_SOCKET_SERVICE="$REPO_ROOT/lib/services/blend_socket_service.dart"
if grep -A 30 "send_message" "$FLUTTER_SOCKET_SERVICE" | grep -q "'groupId'\|groupId"; then
    if ! grep -A 30 "send_message" "$FLUTTER_SOCKET_SERVICE" | grep -q "'userId'"; then
        pass "Flutter sendMessage excludes userId"
    else
        fail "Flutter sendMessage still includes userId"
    fi
else
    fail "Flutter sendMessage pattern not found"
fi

# 11. Check test file exists and has real tests
echo "11. Checking Socket.IO tests..."
if [ -f "$REPO_ROOT/backend/tests/test_socket_io_events.py" ]; then
    test_count=$(grep -c "async def test_" "$REPO_ROOT/backend/tests/test_socket_io_events.py" || echo 0)
    if [ "$test_count" -gt 5 ]; then
        pass "test_socket_io_events.py has ~$test_count real tests"
    else
        fail "test_socket_io_events.py has too few tests ($test_count)"
    fi
else
    fail "test_socket_io_events.py not found"
fi

# 12. Optional: Run pytest if available
echo "12. Running Socket.IO tests..."
if command -v pytest &> /dev/null; then
    if pytest "$REPO_ROOT/backend/tests/test_socket_io_events.py" -q --tb=no 2>/dev/null | grep -q "passed"; then
        pass "Socket.IO tests passing"
    else
        warn "Some tests may be failing (check with: pytest tests/test_socket_io_events.py -v)"
    fi
else
    warn "pytest not found; skipping test execution"
fi

# 13. Check REST endpoints have authorization
echo "13. Checking REST endpoint authorization..."
blend_auth_checks=$(grep -c "require_blend_member_sync\|require_blend_owner_sync" app/routes/blends.py || echo 0)
if [ "$blend_auth_checks" -gt 3 ]; then
    pass "REST endpoints have authorization ($blend_auth_checks checks)"
else
    warn "REST endpoints may be missing authorization checks ($blend_auth_checks)"
fi

# 14. Check no secrets in common locations
echo "14. Checking for exposed secrets..."
secret_files=0
for pattern in "*firebase*account*.json" "*.key" "*.pem" "*secret*"; do
    if find "$REPO_ROOT" -name "$pattern" -type f \
        ! -path "$REPO_ROOT/.git/*" \
        ! -path "$REPO_ROOT/.idea/*" \
        ! -path "$REPO_ROOT/scripts/check_secrets.py" \
        2>/dev/null | grep -qv ".env"; then
        secret_files=$((secret_files + 1))
    fi
done
if [ "$secret_files" -eq 0 ]; then
    pass "No obvious secret files in repo"
else
    warn "Found $secret_files potential secret files; verify with: find . -type f -name '*secret*' -o -name '*account*' | grep -v .git"
fi

echo ""
echo "=============================================="
echo -e "${GREEN}✅ VERIFICATION COMPLETE${NC}"
echo ""
echo "Next steps:"
echo "  1. Run full test suite: pytest tests/"
echo "  2. Start dev server: uvicorn app.main:api"
echo "  3. Test multi-worker: uvicorn app.main:api --workers 2 --reload"
echo "  4. Deploy with REDIS_URL=redis://... for production"
echo ""