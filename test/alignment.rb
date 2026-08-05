# Alignment
#
# Visual test for symbolic `x:` / `y:` alignment and per-edge `padding:`.
# Uses the full viewport, so this test does NOT carry the standard
# header bar — that would conflict with `:top`-anchored elements.
#
# Layered demos:
#   * eight perimeter markers — every (:left/:center/:right, :top/:center/
#     :bottom) anchor pair except the center cell
#   * centered live frame readout — `content` (and width) changes every
#     frame; should stay centered through every change
#   * bottom-center Button with `padding_bottom` lifting it above the
#     bottom-row markers without clobbering its alignment intent
#   * Image at top-right with uniform padding — anchored Image works
#   * Square at top-left with asymmetric padding — `padding_top` and
#     `padding_left` differ, shows per-edge override
#   * animated Sprite at bottom-left with padding — anchored Sprite works
#   * full-width strip above the bottom row — `:left, :bottom` Rectangle
#     stretched across the viewport, padded off the bottom
#
# Resize the window to confirm everything follows the new viewport.

require 'ruby2d'

IMG_DIR = "#{Ruby2D.test_images}".freeze

W = 900
H = 600

set title: 'Ruby 2D — Alignment', width: W, height: H, resizable: true
set close_on_esc: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

# Demo hue for the asymmetric-padding square.
TEAL    = [0.30, 0.80, 0.85, 1].freeze

set background: BG

# --- 3x3 anchor markers -----------------------------------------------------
#
# Eight labeled markers at the perimeter and edge-midpoints. The center
# cell is reserved for the live frame readout below.

MARKER_W = 100
MARKER_H = 30

%i[left center right].each do |xa|
  %i[top center bottom].each do |ya|
    next if xa == :center && ya == :center  # reserved for live readout

    Rectangle.new(x: xa, y: ya, width: MARKER_W, height: MARKER_H,
                  color: BG, stroke_color: LINE_HI, stroke_width: 1)
    Text.new("#{xa.inspect}, #{ya.inspect}", x: xa, y: ya,
             size: 10, color: DIM)
  end
end

# --- Center: live frame readout --------------------------------------------
#
# `content` changes every frame; width changes when digit count rolls
# over. The text should stay centered through every change.

readout = Text.new('Frame: 0', x: :center, y: :center,
                   size: 48, color: ACCENT)

dims = Text.new('viewport ?x?', x: :center, y: :center,
                size: 12, color: DIM)

# --- Bottom-center: Button --------------------------------------------------

clicks = 0
btn = Button.new(x: :center, y: :bottom, width: 220, height: 40,
                 padding_bottom: 60,
                 label: 'click me', label_size: 12,
                 color: BG, stroke_color: LINE_HI, stroke_width: 1,
                 label_color: TEXT,
                 hover_color: :auto,
                 pressed_color: ACCENT, pressed_label_color: BG) do
  clicks += 1
  btn.label = "clicked: #{clicks}"
end

# --- Top-right: Image with uniform padding ---------------------------------

Image.new("#{IMG_DIR}/colors.png",
          x: :right, y: :top, width: 56, height: 56, padding: 80)
Text.new('Image · padding: 80',
         x: :right, y: :top, padding_top: 144, padding_right: 80,
         size: 10, color: DIM)

# --- Top-left: Square with asymmetric padding ------------------------------
#
# `padding_top` and `padding_left` differ, demonstrating per-edge override.

Square.new(x: :left, y: :top, size: 56, color: TEAL,
           padding_top: 80, padding_left: 30)
Text.new('Square · padding_top: 80, padding_left: 30',
         x: :left, y: :top, padding_top: 144, padding_left: 30,
         size: 10, color: DIM)

# --- Bottom-left: animated Sprite with padding -----------------------------

sprite = Sprite.new("#{Ruby2D.test_spritesheets}/coin.png",
                    x: :left, y: :bottom, padding: 80,
                    clip_width: 84, time: 80, loop: true)
sprite.play
Text.new('Sprite · padding: 80',
         x: :left, y: :bottom, padding_left: 80, padding_bottom: 64,
         size: 10, color: DIM)

# --- Above the bottom row: full-width strip --------------------------------
#
# A Rectangle the width of the viewport, anchored to the bottom edge
# with enough padding_bottom to clear the bottom-row markers and the
# button.

strip = Rectangle.new(x: :left, y: :bottom, width: W, height: 1,
                      color: LINE, padding_bottom: 120)

# --- Update loop -----------------------------------------------------------

update do
  readout.content = "Frame: #{Window.frames}"
  dims.content    = "viewport #{Window.viewport_width}x#{Window.viewport_height}"
  # Pin dims just below the readout each frame, since readout's y is
  # recomputed from `:center` against the live viewport height.
  dims.y = readout.y + readout.height + 4
  # Stretch the bottom strip across the live viewport width.
  strip.width = Window.viewport_width
end

show
