#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-09 ADVANCED POS & SUPPLY CHAIN VERIFICATION"
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
echo "[1] Checking Advanced POS & Supply Chain Source Modules..."
check_file "packages/pos/pubspec.yaml"
check_file "packages/pos/lib/pos.dart"
check_file "packages/pos/lib/src/tax_discount_engine.dart"
check_file "packages/pos/lib/src/barcode_engine.dart"
check_file "packages/pos/lib/src/thermal_printer.dart"
check_file "packages/pos/lib/src/procurement_service.dart"
check_file "packages/pos/lib/src/stock_count_service.dart"
check_file "packages/database/lib/src/schema/schema_v5.dart"

echo ""
echo "[2] Checking Advanced POS Test Suite..."
check_file "tests/unit/advanced_pos_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/pos/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/pos (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id in packages/pos"
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
echo "[5] Running Dart Static Analysis on POS and Database Packages..."
dart analyze packages/pos packages/database

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 60 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-09 ADVANCED POS & SUPPLY CHAIN VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
