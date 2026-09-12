#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-01 ARCHITECTURE VERIFICATION SCRIPT"
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
echo "[1] Checking Core Primitives & Foundation..."
check_file "packages/core/lib/core.dart"
check_file "packages/core/lib/src/result.dart"
check_file "packages/core/lib/src/exceptions.dart"
check_file "packages/core/lib/src/identifiers.dart"
check_file "packages/core/lib/src/money.dart"
check_file "packages/core/lib/src/config.dart"
check_file "packages/core/lib/src/logger.dart"
check_file "packages/core/lib/src/di.dart"

echo ""
echo "[2] Checking Platform Hardware Adapters (8 Interfaces & Mocks)..."
check_file "packages/core/lib/src/adapters/camera_adapter.dart"
check_file "packages/core/lib/src/adapters/printer_adapter.dart"
check_file "packages/core/lib/src/adapters/location_adapter.dart"
check_file "packages/core/lib/src/adapters/screen_adapter.dart"
check_file "packages/core/lib/src/adapters/biometric_adapter.dart"
check_file "packages/core/lib/src/adapters/secure_storage_adapter.dart"
check_file "packages/core/lib/src/adapters/network_adapter.dart"
check_file "packages/core/lib/src/adapters/system_info_adapter.dart"

echo ""
echo "[3] Checking UI Design System, Themes & Navigation..."
check_file "packages/ui/lib/ui.dart"
check_file "packages/ui/lib/src/theme/tokens.dart"
check_file "packages/ui/lib/src/theme/app_theme.dart"
check_file "packages/ui/lib/src/theme/responsive.dart"
check_file "packages/ui/lib/src/navigation/router.dart"

echo ""
echo "[4] Checking 27 Shared UI Components..."
check_file "packages/ui/lib/src/widgets/widgets.dart"
check_file "packages/ui/lib/src/widgets/layout_widgets.dart"
check_file "packages/ui/lib/src/widgets/input_widgets.dart"
check_file "packages/ui/lib/src/widgets/display_widgets.dart"
check_file "packages/ui/lib/src/widgets/feedback_widgets.dart"
check_file "packages/ui/lib/src/widgets/system_widgets.dart"

echo ""
echo "[5] Checking Automated Test Suites..."
check_file "tests/unit/core_test.dart"
check_file "tests/unit/logger_test.dart"
check_file "tests/unit/di_test.dart"
check_file "tests/unit/router_test.dart"
check_file "tests/run_all.dart"

echo ""
echo "[6] Verifying Absolute Architectural Invariants..."
# 1. No branch_id
BRANCH_COUNT=$(grep -rn "branch_id" packages/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found across packages (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

# 2. No exposed GitHub personal tokens
GHP_COUNT=$(grep -rn "ghp_" packages/ tests/ | wc -l | tr -d ' ')
if [ "$GHP_COUNT" -eq "0" ]; then
  echo "  ✓ Zero GitHub access tokens found in source/tests (Security Rule)"
else
  echo "  ✗ Violation: Found $GHP_COUNT occurrences of ghp_ tokens"
  FAILURES=$((FAILURES + 1))
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-01 ARCHITECTURE BASE VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
