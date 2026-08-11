#!/bin/sh
# Generate, patch, compile and link the Spinel square demo.
#
#   ./spinel/tools/link_square.sh
#   FRAMES=60 SHOT=spinel/scratch/square.png ./spinel/scratch/square.bin
#
# Run from the repo root. Finds Spinel via spinel_path.sh, so no path has to be
# set by hand. Builds the `RUBY2D_NO_RUBY` core on first use and rebuilds it
# whenever a source under ext/ruby2d/ is newer than the archive.

set -e
. ./spinel/tools/spinel_path.sh

R2D=$(pwd)
CORE="$R2D/spinel/scratch/core"
LIBS="$R2D/assets/platform/macos-arm64/lib"

ARCHIVE="$CORE/libruby2d_core.a"

# The archive was once built and then reused forever, so an edit to ext/ruby2d/
# linked the previous build instead. That surfaces as an undefined symbol when a
# function is added, but a changed body would silently keep the old behaviour —
# so the cache tracks its inputs.
STALE=""
if [ -f "$ARCHIVE" ]; then
  STALE=$(find "$R2D/ext/ruby2d" \( -name '*.c' -o -name '*.h' \) \
               -newer "$ARCHIVE" -print -quit)
fi

if [ ! -f "$ARCHIVE" ] || [ -n "$STALE" ]; then
  echo "building the Ruby-free core"
  mkdir -p "$CORE"
  for f in ruby2d window shapes fps font; do
    cc -c -O2 -DRUBY2D_NO_RUBY -I"$R2D/ext/ruby2d" -I"$R2D/assets/platform/include" \
       "$R2D/ext/ruby2d/$f.c" -o "$CORE/$f.o"
  done
  ar rcs "$ARCHIVE" "$CORE"/ruby2d.o "$CORE"/window.o \
         "$CORE"/shapes.o "$CORE"/fps.o "$CORE"/font.o
fi

ruby spinel/tools/build_square.rb

# `-ferror-limit=0`: clang stops at 20 by default, which makes a real error
# count read as a plateau. The frameworks are what SDL3 needs on macOS.
FW="cc -ferror-limit=0 \
 -framework AVFoundation -framework AudioToolbox -framework Carbon \
 -framework Cocoa -framework CoreAudio -framework CoreHaptics \
 -framework CoreMedia -framework ForceFeedback -framework GameController \
 -framework IOKit -framework Metal -framework QuartzCore \
 -framework UniformTypeIdentifiers"

"$SPINEL" spinel/scratch/square.rb --cc="$FW" \
  --link "$ARCHIVE" \
  --link "$LIBS/libSDL3_ttf.a"   --link "$LIBS/libSDL3_image.a" \
  --link "$LIBS/libSDL3_mixer.a" --link "$LIBS/libSDL3.a" \
  -o spinel/scratch/square.bin

echo "built spinel/scratch/square.bin"
