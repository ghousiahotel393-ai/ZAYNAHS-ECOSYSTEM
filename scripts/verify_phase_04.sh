#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-04 STORAGE & FILE FOUNDATION VERIFICATION"
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
echo "[1] Checking Storage Package & Source Modules..."
check_file "packages/storage/pubspec.yaml"
check_file "packages/storage/lib/storage.dart"
check_file "packages/storage/lib/src/storage_taxonomy.dart"
check_file "packages/storage/lib/src/file_storage_service.dart"
check_file "packages/storage/lib/src/chunked_stream_service.dart"
check_file "packages/storage/lib/src/deduplication_service.dart"

echo ""
echo "[2] Checking Schema v2 & Master Schema Parity..."
check_file "packages/database/lib/src/schema/schema_v2.dart"
if cmp -s "docs/database/MASTER_SCHEMA.md" "MASTER_SCHEMA.md"; then
  echo "  ✓ 100% byte-for-byte parity between canonical and root MASTER_SCHEMA.md"
else
  echo "  ✗ MASTER_SCHEMA divergence detected!"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[3] Checking Storage Test Suite..."
check_file "tests/unit/storage_test.dart"

echo ""
echo "[4] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/storage/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/storage (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[5] Running Dart Static Analysis on Storage Package..."
dart analyze packages/storage

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 36 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-04 STORAGE FOUNDATION VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
