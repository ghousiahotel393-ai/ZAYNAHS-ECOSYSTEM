#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-14 CROSS-PLATFORM & RESPONSIVE VERIFICATION"
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
echo "[1] Checking Cross-Platform Source Modules..."
check_file "packages/ui/lib/src/theme/responsive.dart"
check_file "packages/ui/lib/src/theme/tokens.dart"
check_file "packages/core/lib/src/adapters/system_info_adapter.dart"
check_file "packages/core/lib/src/adapters/camera_adapter.dart"
check_file "packages/core/lib/src/adapters/printer_adapter.dart"
check_file "packages/core/lib/src/adapters/location_adapter.dart"
check_file "packages/core/lib/src/adapters/screen_adapter.dart"
check_file "packages/core/lib/src/adapters/biometric_adapter.dart"
check_file "packages/core/lib/src/adapters/secure_storage_adapter.dart"
check_file "packages/core/lib/src/adapters/network_adapter.dart"

echo ""
echo "[2] Checking Cross-Platform Test Suite..."
check_file "tests/unit/cross_platform_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/ | wc -l | tr -d ' ')
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
echo "[5] Running Dart Static Analysis across All Monorepo Packages..."
dart analyze packages/core packages/ui packages/database packages/auth packages/storage packages/sync packages/network packages/collaboration packages/pos packages/cctv packages/backup

echo ""
echo "[6] Running Master Automated Dart Test Suite (All 85 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq "0" ]; then
  echo "===================================================="
  echo "  ✓ PHASE-14 CROSS-PLATFORM VERIFICATION COMPLETE: ALL PASSING"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ PHASE-14 VERIFICATION FAILED WITH $FAILURES ISSUES"
  echo "===================================================="
  exit 1
fi
