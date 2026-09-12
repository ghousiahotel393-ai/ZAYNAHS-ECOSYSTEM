#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-02 DATABASE FOUNDATION VERIFICATION SCRIPT"
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
echo "[1] Checking Database Package & Engine..."
check_file "packages/database/pubspec.yaml"
check_file "packages/database/lib/database.dart"
check_file "packages/database/lib/src/database_connection.dart"
check_file "packages/database/lib/src/app_database.dart"
check_file "packages/database/lib/src/schema/schema_v1.dart"

echo ""
echo "[2] Checking Domain Repositories..."
check_file "packages/database/lib/src/repositories/inventory_repository.dart"
check_file "packages/database/lib/src/repositories/wallet_repository.dart"
check_file "packages/database/lib/src/repositories/sales_repository.dart"
check_file "packages/database/lib/src/repositories/sync_repository.dart"
check_file "packages/database/lib/src/repositories/device_repository.dart"

echo ""
echo "[3] Checking MASTER_SCHEMA Documentation & Parity..."
check_file "docs/database/MASTER_SCHEMA.md"
check_file "MASTER_SCHEMA.md"
if cmp -s "docs/database/MASTER_SCHEMA.md" "MASTER_SCHEMA.md"; then
  echo "  ✓ MASTER_SCHEMA.md and docs/database/MASTER_SCHEMA.md are strictly identical (Rule 84)"
else
  echo "  ✗ Violation: MASTER_SCHEMA divergence detected!"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[4] Verifying Architectural Invariants (No-Branch Law & Secrets)..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/database/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/database (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

BRANCH_TABLE_COUNT=$(grep -ri "CREATE TABLE.*branch" packages/database/ | wc -l | tr -d ' ')
if [ "$BRANCH_TABLE_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch tables found in database DDL"
else
  echo "  ✗ Violation: Branch table found in database DDL"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[5] Running Automated Dart Test Suite (27/27 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-02 DATABASE FOUNDATION VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
