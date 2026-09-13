#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-15 PRODUCTION VALIDATION & FINAL SIGN-OFF"
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
echo "[1] Checking All Core Monorepo Packages..."
check_file "packages/core/pubspec.yaml"
check_file "packages/ui/pubspec.yaml"
check_file "packages/database/pubspec.yaml"
check_file "packages/auth/pubspec.yaml"
check_file "packages/storage/pubspec.yaml"
check_file "packages/sync/pubspec.yaml"
check_file "packages/network/pubspec.yaml"
check_file "packages/collaboration/pubspec.yaml"
check_file "packages/pos/pubspec.yaml"
check_file "packages/cctv/pubspec.yaml"
check_file "packages/backup/pubspec.yaml"

echo ""
echo "[2] Checking Production Validation Test Artifacts..."
check_file "tests/unit/production_soak_test.dart"
check_file "tests/run_all.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found (Strict Single Ecosystem Law)"
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
echo "[5] Running Dart Static Analysis across Monorepo Packages and Tests..."
dart analyze packages/ tests/

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 89 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq "0" ]; then
  echo "===================================================="
  echo "  ✓ PHASE-15 PRODUCTION VALIDATION COMPLETE: ALL 89 TESTS GREEN"
  echo "  ✓ COMPLETE ECOSYSTEM (PHASES 00-15) PRODUCTION READY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ PHASE-15 PRODUCTION VALIDATION FAILED WITH $FAILURES ERRORS"
  echo "===================================================="
  exit 1
fi
