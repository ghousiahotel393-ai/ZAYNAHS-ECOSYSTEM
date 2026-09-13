#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-05 EVENT & SYNC FOUNDATION VERIFICATION"
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
echo "[1] Checking Sync Package & Source Modules..."
check_file "packages/sync/pubspec.yaml"
check_file "packages/sync/lib/sync.dart"
check_file "packages/sync/lib/src/sync_event.dart"
check_file "packages/sync/lib/src/sync_outbox_queue.dart"
check_file "packages/sync/lib/src/sync_cursor_manager.dart"
check_file "packages/sync/lib/src/sync_conflict_resolver.dart"
check_file "packages/sync/lib/src/sync_engine.dart"

echo ""
echo "[2] Checking Schema v3 & Master Schema Parity..."
check_file "packages/database/lib/src/schema/schema_v3.dart"
if cmp -s "docs/database/MASTER_SCHEMA.md" "MASTER_SCHEMA.md"; then
  echo "  ✓ 100% byte-for-byte parity between canonical and root MASTER_SCHEMA.md"
else
  echo "  ✗ MASTER_SCHEMA divergence detected!"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[3] Checking Sync Test Suite..."
check_file "tests/unit/sync_test.dart"

echo ""
echo "[4] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/sync/ packages/database/lib/src/schema/schema_v3.dart | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/sync & schema_v3 (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[5] Running Dart Static Analysis on Sync Package..."
dart analyze packages/sync

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 41 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-05 EVENT & SYNC FOUNDATION VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
