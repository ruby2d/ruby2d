#!/bin/sh
# Two-sided oracle for `spinel-reduce`, for the **silent** class of bug: the
# program compiles, runs, exits 0, and prints the wrong answer. Its sibling
# `reduce_oracle.sh` handles the loud class, where something crashes.
#
# A candidate is interesting only if CRuby and Spinel both run it cleanly and
# their output differs. Requiring both to succeed is what keeps the reducer from
# deleting the program into something CRuby also rejects — the failure mode that
# wasted two earlier reduction attempts on this branch.
#
#   export SPINEL=/path/to/spinel/bin/spinel
#   spinel-reduce --oracle-cmd "$PWD/spinel/tools/reduce_oracle_diff.sh {}" \
#     -o reduced.rb input.rb
#
# Three of the ten bugs filed from this branch were silent wrong answers, so
# this is the oracle to reach for first.

: "${SPINEL:?set SPINEL to the spinel binary}"

# Absolute path: a bare relative name gets searched on PATH, silently reports
# "command not found", and the oracle reads that as "not interesting".
f=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
BIN="${f%.rb}.bin"

# 1. Still valid Ruby, and still prints something to disagree about.
expected=$(ruby "$f" 2>/dev/null) || exit 1
[ -n "$expected" ] || exit 1

# 2. Still compiles. Delete first — a failed compile leaves the previous binary
# in place, and the old result reads as a fresh success.
rm -f "$BIN"
"$SPINEL" "$f" -o "$BIN" --cc="cc -w" >/dev/null 2>&1 || exit 1
[ -x "$BIN" ] || exit 1

# 3. Still runs cleanly, and still disagrees. A crash is a different bug, so it
# does not count as interesting here.
actual=$("$BIN" 2>/dev/null) || { rm -f "$BIN"; exit 1; }
rm -f "$BIN"

[ "$expected" = "$actual" ] && exit 1
exit 0
