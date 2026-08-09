#!/bin/sh
# Two-sided oracle for `spinel-reduce`: a candidate is only interesting if it is
# BOTH valid Ruby AND miscompiled. That is the reproducer shape Spinel asks for.
#
# An oracle that only greps compiler output is worse than useless — the reducer
# deletes the program into something CRuby rejects too, and the result is a case
# no maintainer can act on. Both earlier attempts here failed exactly that way.
#
#   export SPINEL=/path/to/spinel/bin/spinel
#   spinel-reduce --oracle-cmd "$PWD/spinel/tools/reduce_oracle.sh {}" \
#     -o reduced.rb input.rb
#
# Set EXPECT to the error text that identifies the bug being reduced.

: "${SPINEL:?set SPINEL to the spinel binary}"
EXPECT="${EXPECT:-NoMethodError}"

# Absolute path: a bare relative name gets searched on PATH, silently reports
# "command not found", and the oracle reads that as "not interesting" —
# rejecting a perfectly good input.
f=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
BIN="${f%.rb}.bin"

ruby "$f" >/dev/null 2>&1 || exit 1                  # 1. still valid Ruby
"$SPINEL" "$f" -o "$BIN" >/dev/null 2>&1 || exit 1   # 2. still compiles
[ -x "$BIN" ] || exit 1

out=$("$BIN" 2>&1); rc=$?                            # 3. still fails at run time
rm -f "$BIN"
[ $rc -eq 0 ] && exit 1
echo "$out" | grep -q "$EXPECT" || exit 1
exit 0
