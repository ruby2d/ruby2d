#!/bin/sh
# Two-sided oracle for `spinel-reduce`, for a program that is valid Ruby but
# fails to COMPILE. The third of the set: `reduce_oracle.sh` wants a crash,
# `reduce_oracle_diff.sh` wants a wrong answer, this one wants a build failure.
#
# Spinel has a built-in `--oracle build`, but nothing there requires the
# candidate to still be valid Ruby -- and a reducer left to delete freely will
# happily produce something CRuby rejects too, which is a case no maintainer can
# act on. Both earlier reduction attempts on this branch failed exactly that way.
#
#   export SPINEL=/path/to/spinel/bin/spinel
#   EXPECT='error:' spinel-reduce \
#     --oracle-cmd "$PWD/spinel/tools/reduce_oracle_build.sh {}" \
#     -o reduced.rb input.rb
#
# EXPECT pins which failure is being reduced, so the reducer cannot wander onto
# a different compile error than the one under investigation.

: "${SPINEL:?set SPINEL to the spinel binary}"
EXPECT="${EXPECT:-error:}"

# Absolute path: a bare relative name gets searched on PATH, silently reports
# "command not found", and the oracle reads that as "not interesting".
f=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
BIN="${f%.rb}.bin"

# 1. Still valid Ruby. Runtime output does not matter here, only that CRuby
# accepts and runs it -- the compile failure is the thing being reduced.
ruby "$f" >/dev/null 2>&1 || exit 1

# 2. Still fails to build, with the same diagnostic. Delete the binary first: a
# failed compile leaves the previous one in place and a stale success would
# read as "no longer interesting", throwing away a good candidate.
rm -f "$BIN"
out=$("$SPINEL" "$f" -o "$BIN" --cc="cc -ferror-limit=0" 2>&1)
if [ -x "$BIN" ]; then rm -f "$BIN"; exit 1; fi

echo "$out" | grep -q "$EXPECT" || exit 1
exit 0
