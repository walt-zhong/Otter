#!/bin/bash
# Compile the Otter expression bridge against OTAndroid/src/main/cpp and run
# the macOS assertions in test_main.swift. Does not modify Package.swift.
set -euo pipefail

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export PATH="${DEVELOPER_DIR:-}/usr/bin:${PATH}"

BRIDGE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${BRIDGE_DIR}/../../.." && pwd)"
CPP_DIR="${REPO_ROOT}/OTAndroid/src/main/cpp"
SWIFT_DIR="${REPO_ROOT}/OTIOS/Sources/OtterExpression"
HEADER="${BRIDGE_DIR}/include/OTExpressionBridge.h"

# /usr/bin/xcrun honors DEVELOPER_DIR. Xcode.app does not ship xcrun inside
# Contents/Developer/usr/bin, and xcode-select may point at CommandLineTools.
XCRUN="/usr/bin/xcrun"
SDK="$("${XCRUN}" --sdk macosx --show-sdk-path)"
CXX="$("${XCRUN}" --find clang++)"
SWIFTC="$("${XCRUN}" --find swiftc)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/otter-expression.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "DEVELOPER_DIR=${DEVELOPER_DIR}"
echo "SDK=${SDK}"
"${CXX}" --version

COMMON=(-std=c++17 -stdlib=libc++ -isysroot "${SDK}" -I "${CPP_DIR}")

"${CXX}" "${COMMON[@]}" -c "${CPP_DIR}/OTATSNode.cpp" -o "${WORK}/OTATSNode.o"
"${CXX}" "${COMMON[@]}" -c "${CPP_DIR}/OTWordAnalyze.cpp" -o "${WORK}/OTWordAnalyze.o"
"${CXX}" "${COMMON[@]}" -c "${CPP_DIR}/OTAnalyze.cpp" -o "${WORK}/OTAnalyze.o"
"${CXX}" "${COMMON[@]}" -fobjc-arc -I "${BRIDGE_DIR}/include" \
  -c "${BRIDGE_DIR}/OTExpressionBridge.mm" -o "${WORK}/OTExpressionBridge.o"

"${SWIFTC}" -sdk "${SDK}" \
  -import-objc-header "${HEADER}" \
  -framework Foundation \
  -lc++ \
  -o "${WORK}/expression-test" \
  "${SWIFT_DIR}/ExpressionEngine.swift" \
  "${BRIDGE_DIR}/test_main.swift" \
  "${WORK}/OTAnalyze.o" \
  "${WORK}/OTWordAnalyze.o" \
  "${WORK}/OTATSNode.o" \
  "${WORK}/OTExpressionBridge.o"

"${WORK}/expression-test"
