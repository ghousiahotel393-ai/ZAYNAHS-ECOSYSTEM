#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-11 CCTV MONITORING & RECORDING VERIFICATION"
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
echo "[1] Checking CCTV Source Modules..."
check_file "packages/cctv/pubspec.yaml"
check_file "packages/cctv/lib/cctv.dart"
check_file "packages/cctv/lib/src/camera_source.dart"
check_file "packages/cctv/lib/src/segmented_recorder.dart"
check_file "packages/cctv/lib/src/timeline_playback.dart"
check_file "packages/cctv/lib/src/retention_cleaner.dart"
check_file "packages/database/lib/src/schema/schema_v7.dart"

echo ""
echo "[2] Checking CCTV Test Suite..."
check_file "tests/unit/cctv_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/cctv/ packages/database/ | wc -l | tr -d ' ')
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
echo "[5] Running Dart Static Analysis on CCTV, POS, and Database Packages..."
dart analyze packages/cctv packages/pos packages/database

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 69 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-11 CCTV MONITORING & RECORDING VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
