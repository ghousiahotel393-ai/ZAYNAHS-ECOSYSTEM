#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-12 BACKUP & DISASTER RECOVERY VERIFICATION"
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
echo "[1] Checking Backup & Disaster Recovery Source Modules..."
check_file "packages/backup/pubspec.yaml"
check_file "packages/backup/lib/backup.dart"
check_file "packages/backup/lib/src/zynb_archive.dart"
check_file "packages/backup/lib/src/backup_writer.dart"
check_file "packages/backup/lib/src/projection_rebuilder.dart"
check_file "packages/backup/lib/src/restore_manager.dart"
check_file "packages/database/lib/src/schema/schema_v8.dart"

echo ""
echo "[2] Checking Backup Test Suite..."
check_file "tests/unit/backup_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/backup/ packages/database/ | wc -l | tr -d ' ')
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
echo "[5] Running Dart Static Analysis across Backup, CCTV, POS, and Database Packages..."
dart analyze packages/backup packages/cctv packages/pos packages/database

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 71 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq "0" ]; then
  echo "===================================================="
  echo "  ✓ PHASE-12 & GOLDEN TEST 102 VERIFICATION COMPLETE: ALL PASSING"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ PHASE-12 VERIFICATION FAILED WITH $FAILURES ISSUES"
  echo "===================================================="
  exit 1
fi
