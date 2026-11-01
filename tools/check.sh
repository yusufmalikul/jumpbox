#!/usr/bin/env bash
# Runs every test in tests/ headless and prints one PASS/FAIL line each.
# Exit 0 only when all pass. Use before every commit.
# A broken script can make Godot hang, so each test gets a time limit (perl alarm,
# because macOS has no `timeout` command).
LIMIT="${TEST_LIMIT:-90}"
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1 || true
fails=0
for t in tests/*_test.gd; do
	out="$(perl -e 'alarm shift; exec @ARGV' "$LIMIT" godot --headless --path . -s "$t" 2>&1)"
	code=$?
	# Godot script errors do not always change the exit code, so look for them too.
	if [ $code -ne 0 ] || grep -q "SCRIPT ERROR\|Parse Error" <<<"$out"; then
		[ $code -eq 142 ] && echo "FAIL $t (hung for ${LIMIT}s, killed)" || echo "FAIL $t"; echo "$out" | grep -E "FAIL|ERROR|Error" | head -20
		fails=$((fails + 1))
	else
		echo "PASS $t"
	fi
done
[ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED"
exit $((fails > 0))
