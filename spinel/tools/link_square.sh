#!/bin/sh
# Generate, patch, compile and link the Spinel square demo.
#
#   ./spinel/tools/link_square.sh
#   FRAMES=60 SHOT=spinel/scratch/square.png ./spinel/scratch/square.bin
#
# Run from the repo root. Finds Spinel via spinel_path.sh, so no path has to be
# set by hand. Builds the `RUBY2D_NO_RUBY` core on first use and reuses it
# after; delete spinel/scratch/core to force a rebuild.

set -e
. ./spinel/tools/spinel_path.sh

R2D=$(pwd)
CORE="$R2D/spinel/scratch/core"
LIBS="$R2D/assets/platform/macos-arm64/lib"

if [ ! -f "$CORE/libruby2d_core.a" ]; then
  echo "building the Ruby-free core"
  mkdir -p "$CORE"
  for f in ruby2d window shapes fps font; do
    cc -c -O2 -DRUBY2D_NO_RUBY -I"$R2D/ext/ruby2d" -I"$R2D/assets/platform/include" \
       "$R2D/ext/ruby2d/$f.c" -o "$CORE/$f.o"
  done
  ar rcs "$CORE/libruby2d_core.a" "$CORE"/ruby2d.o "$CORE"/window.o \
         "$CORE"/shapes.o "$CORE"/fps.o "$CORE"/font.o
fi

ruby spinel/tools/build_square.rb
ruby spinel/tools/patch_next.rb    spinel/scratch/square.rb
ruby spinel/tools/patch_capture.rb spinel/scratch/square.rb

# `-ferror-limit=0`: clang stops at 20 by default, which makes a real error
# count read as a plateau. The frameworks are what SDL3 needs on macOS.
FW="cc -ferror-limit=0 \
 -framework AVFoundation -framework AudioToolbox -framework Carbon \
 -framework Cocoa -framework CoreAudio -framework CoreHaptics \
 -framework CoreMedia -framework ForceFeedback -framework GameController \
 -framework IOKit -framework Metal -framework QuartzCore \
 -framework UniformTypeIdentifiers"

"$SPINEL" spinel/scratch/square.rb --cc="$FW" \
  --link "$CORE/libruby2d_core.a" \
  --link "$LIBS/libSDL3_ttf.a"   --link "$LIBS/libSDL3_image.a" \
  --link "$LIBS/libSDL3_mixer.a" --link "$LIBS/libSDL3.a" \
  -o spinel/scratch/square.bin

echo "built spinel/scratch/square.bin"
