#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-13 SYSTEM HARDENING & SECURITY VERIFICATION"
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
echo "[1] Checking Security Hardening Source Modules..."
check_file "packages/auth/lib/src/security_gatekeeper.dart"
check_file "packages/auth/lib/src/secret_scanner.dart"
check_file "packages/core/lib/src/resource_tracker.dart"
check_file "packages/ui/lib/src/navigation/router.dart"

echo ""
echo "[2] Checking Security Test Suite..."
check_file "tests/unit/security_hardening_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/auth/ packages/core/ packages/database/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[4] Verifying Master Schema Parity (Byte-for-Byte)..."
if diff "docs/database/MASTER_SCHEMA.md" "MASTER_SCHEMA.md" > /dev/null; then
  echo "  ✓ 100% byte-for-byte parity between docs/database/MASTER_SCHEMA.md and MASTER_SCHEMA.md"
else
  echo "  ✗ Master schema parity check failed!"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[5] Running Dart Static Analysis across Auth, Core, UI, Backup, CCTV, POS, Database..."
dart analyze packages/auth packages/core packages/ui packages/backup packages/cctv packages/pos packages/database

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 81 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq "0" ]; then
  echo "===================================================="
  echo "  ✓ PHASE-13 & GOLDEN TEST 103 VERIFICATION COMPLETE: ALL PASSING"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ PHASE-13 VERIFICATION FAILED WITH $FAILURES ISSUES"
  echo "===================================================="
  exit 1
fi
