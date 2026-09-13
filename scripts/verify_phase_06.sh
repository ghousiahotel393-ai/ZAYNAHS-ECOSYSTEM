#!/bin/bash
set -e

echo "===================================================="
echo "  PHASE-06 P2P & WEBRTC FOUNDATION VERIFICATION"
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
echo "[1] Checking Network & P2P Source Modules..."
check_file "packages/network/pubspec.yaml"
check_file "packages/network/lib/network.dart"
check_file "packages/network/lib/src/peer_descriptor.dart"
check_file "packages/network/lib/src/lan_discovery_service.dart"
check_file "packages/network/lib/src/signaling_client.dart"
check_file "packages/network/lib/src/datachannel_multiplexer.dart"
check_file "packages/network/lib/src/peer_connection_manager.dart"

echo ""
echo "[2] Checking P2P Test Suite..."
check_file "tests/unit/p2p_test.dart"

echo ""
echo "[3] Verifying Absolute Architectural Invariants..."
BRANCH_COUNT=$(grep -rn "branch_id" packages/network/ | wc -l | tr -d ' ')
if [ "$BRANCH_COUNT" -eq "0" ]; then
  echo "  ✓ Zero branch_id occurrences found in packages/network (Strict Law)"
else
  echo "  ✗ Violation: Found $BRANCH_COUNT occurrences of branch_id"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[4] Running Dart Static Analysis on Network Package..."
dart analyze packages/network

echo ""
echo "[5] Running Master Automated Dart Test Suite (All 46 Tests)..."
dart tests/run_all.dart

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "===================================================="
  echo "  ✓ PHASE-06 P2P & WEBRTC VERIFIED: 100% HEALTHY"
  echo "===================================================="
  exit 0
else
  echo "===================================================="
  echo "  ✗ VERIFICATION FAILED: $FAILURES issues detected"
  echo "===================================================="
  exit 1
fi
