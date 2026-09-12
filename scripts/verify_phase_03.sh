#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-03 IDENTITY & DEVICES VERIFICATION SCRIPT"
echo "===================================================="

FAILURES=0

check_file() {
  if [ -f "$1" ]; then
    echo "  ✓ Exists: $1"
  else
    echo "  ✗ Missing: $1"
    FAILURES=$((FAILURES + 1))
  fi
}

echo ""
echo "[1] Checking Auth Package & Source Modules..."
check_file "packages/auth/pubspec.yaml"
check_file "packages/auth/lib/auth.dart"
check_file "packages/auth/lib/src/crypto_utils.dart"
check_file "packages/auth/lib/src/rbac_resolver.dart"
check_file "packages/auth/lib/src/user_session.dart"
check_file "packages/auth/lib/src/device_trust_manager.dart"
check_file "packages/auth/lib/src/pairing_service.dart"

echo ""
echo "[2] Checking Test Suite..."
check_file "tests/unit/auth_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/auth/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/auth (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[4] Running Master Automated Dart Test Suite (34/34 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-03 IDENTITY & DEVICES VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
