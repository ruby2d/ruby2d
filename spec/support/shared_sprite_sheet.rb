require 'ruby2d'

# Loading the test sprite sheet (parsing the XML + decoding a 2321x2321 PNG)
# costs ~60 ms. Re-evaluating it in a per-example `let` block dominated the
# RSpec run, so tests that only read from the sheet share this one instance.
module SharedSpriteSheet
  PATH = "#{Ruby2D.test_spritesheets}/spritesheet.xml".freeze

  def self.instance
    @instance ||= Ruby2D::SpriteSheet.new(PATH)
  end
end

# Shared `let(:sheet)` plus the animation-clock and frame-stub helpers used by
# the sprite specs. Include with `include_context 'sprite sheet'`.
RSpec.shared_context 'sprite sheet' do
  let(:sheet) { SharedSpriteSheet.instance }

  # Advance the animation by exactly one frame. Resets the budget so each tick
  # is an independent one-frame step (no carryover), then drives `update` with
  # just over one frame's worth of delta time (in seconds).
  def tick(sprite)
    ft = sprite.instance_variable_get(:@frame_time) || 300
    sprite.instance_variable_set(:@frame_budget, 0.0)
    sprite.update((ft + 1) / 1000.0)
  end

  # Drive `update` by an explicit elapsed time (ms), independent of any prior
  # call: reset the accumulated budget first so each step measures a fresh
  # delta, then update (which scales by @speed). `update` takes seconds.
  def advance_ms(sprite, ms)
    sprite.instance_variable_set(:@frame_budget, 0.0)
    sprite.update(ms / 1000.0)
  end

  # Stub SpriteSheet#frame for one name, passing every other query through to
  # the real lookup. Used to inject rotated/trimmed rects.
  def stub_frame(sheet, name, rect)
    original = sheet.method(:frame)
    allow(sheet).to receive(:frame) do |query|
      query == name ? rect : original.call(query)
    end
  end
end
