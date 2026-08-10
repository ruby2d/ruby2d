#!/bin/sh
# Run a command with a time cap, printing TIMEOUT if it is still going.
#
#   ./spinel/tools/run_capped.sh ./spinel/scratch/subset.bin
#   CAP=30 ./spinel/tools/run_capped.sh ./some.bin
#
# Two of the open Spinel bugs are infinite loops, so an uncapped run of a
# freshly compiled binary can hang indefinitely. macOS ships no timeout(1),
# hence perl's alarm.

CAP="${CAP:-5}"
perl -e 'alarm shift; exec @ARGV or exit 127' "$CAP" "$@" 2>&1
rc=$?

# perl's alarm kills with SIGALRM: 142 through a shell, 14 raw.
if [ $rc -eq 142 ] || [ $rc -eq 14 ]; then
  echo "TIMEOUT (${CAP}s)"
fi
exit 0
