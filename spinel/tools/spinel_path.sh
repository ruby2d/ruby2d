#!/bin/sh
# Resolve the Spinel binary without anyone hardcoding a path.
#
#   . ./spinel/tools/spinel_path.sh     # sets $SPINEL, or exits with guidance
#
# Order matches `find_spinel` in lib/ruby2d/cli/spinel.rb, plus a sibling
# checkout — the layout most people end up with, and the one that keeps a
# machine-specific path out of every recipe in ../README.md.
#
#   $SPINEL          an explicit choice already made
#   $RUBY2D_SPINEL   the override the build path itself honors
#   ../spinel        a checkout beside this repo
#   $PATH

if [ -z "$SPINEL" ] && [ -n "$RUBY2D_SPINEL" ]; then
  SPINEL="$RUBY2D_SPINEL"
fi

if [ -z "$SPINEL" ] && [ -x "../spinel/bin/spinel" ]; then
  SPINEL=$(cd ../spinel && pwd)/bin/spinel
fi

if [ -z "$SPINEL" ]; then
  SPINEL=$(command -v spinel 2>/dev/null)
fi

if [ -z "$SPINEL" ] || [ ! -x "$SPINEL" ]; then
  echo "No spinel binary found. Build one and either put it on PATH, clone it" >&2
  echo "beside this repo as ../spinel, or point SPINEL at it:" >&2
  echo >&2
  echo "  git clone https://github.com/matz/spinel.git ../spinel" >&2
  echo "  (cd ../spinel && make deps && make)" >&2
  echo >&2
  echo "See \"Setup\" in spinel/README.md." >&2
  return 1 2>/dev/null || exit 1
fi

export SPINEL
