#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-08 UNIVERSAL POS FOUNDATION VERIFICATION"
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
echo "[1] Checking POS Source Modules..."
check_file "packages/pos/pubspec.yaml"
check_file "packages/pos/lib/pos.dart"
check_file "packages/pos/lib/src/business_template.dart"
check_file "packages/pos/lib/src/negative_stock_policy.dart"
check_file "packages/pos/lib/src/pos_cart.dart"
check_file "packages/pos/lib/src/universal_pos_engine.dart"
check_file "packages/database/lib/src/schema/schema_v4.dart"

echo ""
echo "[2] Checking POS & Golden Test 100 Suite..."
check_file "tests/unit/pos_test.dart"

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
echo "[6] Running Master Automated Dart Test Suite (All 54 Tests, including Golden Test 100)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-08 UNIVERSAL POS FOUNDATION VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
