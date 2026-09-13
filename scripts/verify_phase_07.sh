#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-07 COMMUNICATION & COLLABORATION VERIFICATION"
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
echo "[1] Checking Collaboration Source Modules..."
check_file "packages/collaboration/pubspec.yaml"
check_file "packages/collaboration/lib/collaboration.dart"
check_file "packages/collaboration/lib/src/chat_message.dart"
check_file "packages/collaboration/lib/src/chat_service.dart"
check_file "packages/collaboration/lib/src/file_transfer_protocol.dart"
check_file "packages/collaboration/lib/src/call_session_coordinator.dart"
check_file "packages/collaboration/lib/src/privacy_sharing_manager.dart"

echo ""
echo "[2] Checking Collaboration & Golden Test 104 Suite..."
check_file "tests/unit/collaboration_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/collaboration/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/collaboration (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[4] Running Dart Static Analysis on Collaboration Package..."
dart analyze packages/collaboration

echo ""
echo "[5] Running Master Automated Dart Test Suite (All 50 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-07 COMMUNICATION & COLLABORATION VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
