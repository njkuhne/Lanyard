#!/bin/sh
# Runs the tests with coverage and holds the logic files to 100% line coverage.
# Views are checked by snapshot tests; system wiring is excluded (see CLAUDE.md).
set -e
cd "$(dirname "$0")/.."

LOGIC="ConfigParser ConfigStore EditorModel EditorState Model ServiceKind SymbolCatalog"

# Extra arguments go to `swift test`, e.g. `--skip SnapshotTests` on CI.
swift test --enable-code-coverage "$@" >/dev/null
JSON=$(swift test --show-codecov-path)
PROFDATA="$(dirname "$JSON")/default.profdata"
BIN="$(dirname "$(dirname "$JSON")")/LanyardTests.xctest/Contents/MacOS/LanyardTests"
FILES=$(for f in $LOGIC; do printf "Sources/Lanyard/%s.swift " "$f"; done)

echo "Logic line coverage:"
# shellcheck disable=SC2086
xcrun llvm-cov report "$BIN" -instr-profile "$PROFDATA" $FILES \
    | sed "s#$PWD/##" | awk 'NR > 2 && NF > 5 { printf "  %-24s %6s lines  %4s missed  %s\n", $1, $8, $9, $10 }'

# shellcheck disable=SC2086
MISSED=$(xcrun llvm-cov report "$BIN" -instr-profile "$PROFDATA" $FILES | awk '$1 == "TOTAL" { print $9 }')
if [ "$MISSED" != "0" ]; then
    echo
    echo "Untested lines:"
    # shellcheck disable=SC2086
    xcrun llvm-cov show "$BIN" -instr-profile "$PROFDATA" $FILES -format=text \
        | sed "s#$PWD/##" | awk '/^Sources\// { file = $0 } /^ *[0-9]+\| *0\|/ { print "  " file " " $0 }'
    exit 1
fi
