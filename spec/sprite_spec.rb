RSpec.describe Ruby2D::Sprite do
  subject { Sprite.new path }
  let(:path) { "#{Ruby2D.test_spritesheets}/coin.png" }
  let(:not_found_path) { "#{Ruby2D.test_spritesheets}/bad_sprite_sheet.png" }

  describe '#new' do
    context 'without atlas' do
      include_examples 'image-loading tests'
      include_examples 'image-like tests', Sprite
    end
  end

  include_examples 'image-like attributes', Sprite

  describe 'with a SpriteSheet source' do
    include_context 'sprite sheet'

    it 'shares the sheet texture without re-loading' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect(sprite.path).to eq(sheet.image_path)
      expect(sprite.instance_variable_get(:@ext_image))
        .to be(sheet.texture.instance_variable_get(:@ext_image))
      expect(sprite.sheet).to be(sheet)
    end

    it 'refuses resize! because the sheet texture is shared' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect { sprite.resize!(64, 64) }
        .to raise_error(Ruby2D::Error, /SpriteSheet-backed/)
    end

    it 'clips to the named frame' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect(sprite.clip_x).to eq(0)
      expect(sprite.clip_y).to eq(0)
      expect(sprite.clip_width).to eq(128)
      expect(sprite.clip_height).to eq(128)
      expect(sprite.width).to eq(128)
      expect(sprite.height).to eq(128)
    end

    it 'falls back to the first sheet frame when no frame: is given' do
      sprite = Sprite.new(sheet, add: false)
      first = sheet.frame(sheet.frame_names.first)
      expect(sprite.clip_width).to eq(first[:width])
      expect(sprite.clip_height).to eq(first[:height])
    end

    it 'raises when frame: is not a known sheet frame' do
      expect { Sprite.new(sheet, frame: 'no_such_frame', add: false) }
        .to raise_error(Ruby2D::Error, /no_such_frame/)
    end

    it 'raises when frame: is given without a sheet' do
      expect { Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", frame: 'x', add: false) }
        .to raise_error(Ruby2D::Error, /SpriteSheet/)
    end

    it 'resolves animations defined as arrays of frame names' do
      sprite = Sprite.new(sheet,
                          animations: { stones: %w[block_blue block_coin block_green] },
                          add: false)
      anims = sprite.instance_variable_get(:@animations)
      expect(anims[:stones]).to be_a(Array)
      expect(anims[:stones].length).to eq(3)
      anims[:stones].each { |frame| expect(frame).to include(:x, :y, :width, :height) }
    end

    it 'allows mixing frame names and per-frame timing' do
      sprite = Sprite.new(sheet,
                          animations: { stones: [
                            { name: 'block_blue', time: 100 },
                            'block_coin'
                          ] },
                          add: false)
      stones = sprite.instance_variable_get(:@animations)[:stones]
      expect(stones[0]).to include(time: 100, width: 128)
      expect(stones[1]).not_to include(:time)
    end

    it 'raises when an animation references an unknown frame' do
      expect do
        Sprite.new(sheet, animations: { broken: ['no_such'] }, add: false)
      end.to raise_error(Ruby2D::Error, /no_such/)
    end

    it 'does not auto-create the :default horizontal-strip animation' do
      sprite = Sprite.new(sheet,
                          animations: { stones: %w[block_blue block_coin] },
                          add: false)
      expect(sprite.instance_variable_get(:@animations).key?(:default)).to be false
    end
  end

  describe 'animation lifecycle' do
    include_context 'sprite sheet'

    let(:three_frame_sprite) do
      Sprite.new(sheet,
                 animations: { stones: %w[block_blue block_coin block_green] },
                 add: false)
    end

    it 'cycles through frames when looping' do
      sprite = three_frame_sprite
      sprite.play(animation: :stones, loop: true)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)

      tick(sprite)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
      tick(sprite)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
      tick(sprite)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)
      expect(sprite.instance_variable_get(:@playing)).to be true
    end

    it 'holds on the last frame when non-looping' do
      sprite = three_frame_sprite
      sprite.play(animation: :stones, loop: false)
      expected_last_clip = sheet['block_green']

      tick(sprite); tick(sprite); tick(sprite)

      expect(sprite.instance_variable_get(:@playing)).to be false
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
      expect(sprite.clip_x).to eq(expected_last_clip[:x])
      expect(sprite.clip_y).to eq(expected_last_clip[:y])
    end

    it 'fires the done_proc exactly once when a non-looping animation ends' do
      sprite = three_frame_sprite
      calls = 0
      sprite.play(animation: :stones, loop: false) { calls += 1 }

      tick(sprite); tick(sprite); tick(sprite)
      expect(calls).to eq(1)

      # Subsequent updates do nothing (sprite is paused on the last frame)
      tick(sprite); tick(sprite)
      expect(calls).to eq(1)
    end

    it 'holds a single-frame non-looping animation on its only frame' do
      sprite = Sprite.new(sheet,
                          animations: { pose: ['block_blue'] },
                          add: false)
      expected = sheet['block_blue']
      sprite.play(animation: :pose, loop: false)

      tick(sprite); tick(sprite)

      expect(sprite.instance_variable_get(:@playing)).to be false
      expect(sprite.clip_x).to eq(expected[:x])
      expect(sprite.clip_y).to eq(expected[:y])
    end

    it 'stop() after a hold reverts to the default-animation frame' do
      sprite = Sprite.new(sheet,
                          animations: { idle: ['block_blue'], pose: ['block_green'] },
                          add: false)
      sprite.play(animation: :pose, loop: false)
      tick(sprite); tick(sprite)
      expect(sprite.clip_x).to eq(sheet['block_green'][:x])

      sprite.stop
      expect(sprite.clip_x).to eq(sheet['block_blue'][:x])
    end

    it 'play() applies an explicit loop: on the already-playing fast path without restarting' do
      sprite = three_frame_sprite
      sprite.play(animation: :stones, loop: true)
      tick(sprite)  # advance to frame 1
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)

      # Same animation, now loop: false — must take effect but NOT jump to frame 0
      sprite.play(animation: :stones, loop: false)
      expect(sprite.looping?).to be false
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
    end

    it 'play() installs a new completion block on the already-playing fast path' do
      sprite = three_frame_sprite
      sprite.play(animation: :stones, loop: false)  # no block yet
      calls = 0
      sprite.play(animation: :stones, loop: false) { calls += 1 }  # same anim, add a block

      tick(sprite); tick(sprite); tick(sprite)
      expect(calls).to eq(1)
    end

    it 'play() with no loop: preserves looping and never restarts on the fast path' do
      sprite = three_frame_sprite
      sprite.play(animation: :stones, loop: true)
      tick(sprite)  # advance to frame 1
      sprite.play(animation: :stones)  # per-frame style re-call, no args
      expect(sprite.looping?).to be true
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
    end

    it 'loop= toggles looping mid-play without restarting' do
      sprite = three_frame_sprite
      sprite.play(animation: :stones, loop: true)
      tick(sprite)  # advance to frame 1
      sprite.loop = false
      expect(sprite.looping?).to be false
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)

      # With looping off it now holds on the last frame instead of cycling
      tick(sprite); tick(sprite)
      expect(sprite.instance_variable_get(:@playing)).to be false
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
    end

    it 'raises a clear error when playing an undefined animation' do
      expect { three_frame_sprite.play(animation: :nope) }
        .to raise_error(Ruby2D::Error, /not defined/)
    end

    it 'raises a clear error when an animation has no frames' do
      expect { Sprite.new(sheet, animations: { empty: [] }, add: false) }
        .to raise_error(Ruby2D::Error, /`empty` has no frames/)
    end
  end

  describe 'pause and resume' do
    include_context 'sprite sheet'

    let(:cycle_sprite) do
      Sprite.new(sheet,
                 animations: { stones: %w[block_blue block_coin block_green] },
                 add: false)
    end

    it 'pause freezes the current frame and resume picks up from there' do
      sprite = cycle_sprite
      sprite.play(animation: :stones, loop: true)
      tick(sprite)  # advance to frame 1
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)

      sprite.pause
      expect(sprite.paused?).to be true

      tick(sprite)  # update should be a no-op while paused
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)

      sprite.resume
      expect(sprite.paused?).to be false

      tick(sprite)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
    end

    it 'playing? reflects active animation state' do
      sprite = cycle_sprite
      expect(sprite.playing?).to be false

      sprite.play(animation: :stones, loop: true)
      expect(sprite.playing?).to be true

      sprite.pause
      expect(sprite.playing?).to be false

      sprite.resume
      expect(sprite.playing?).to be true

      sprite.stop
      expect(sprite.playing?).to be false
    end

    it 'playing? is false after a non-looping animation finishes' do
      sprite = cycle_sprite
      sprite.play(animation: :stones, loop: false)
      expect(sprite.playing?).to be true

      tick(sprite); tick(sprite); tick(sprite)
      expect(sprite.playing?).to be false
    end

    it 'pause is a no-op when no animation is playing' do
      sprite = cycle_sprite
      expect(sprite.paused?).to be false
      sprite.pause
      expect(sprite.paused?).to be false
      expect(sprite.instance_variable_get(:@playing)).to be false
    end

    it 'resume is a no-op when not paused' do
      sprite = cycle_sprite
      sprite.play(animation: :stones, loop: true)
      sprite.resume
      expect(sprite.instance_variable_get(:@playing)).to be true
      expect(sprite.paused?).to be false
    end

    it 'play clears the paused state' do
      sprite = cycle_sprite
      sprite.play(animation: :stones, loop: true)
      sprite.pause
      sprite.play(animation: :stones, loop: true)
      expect(sprite.paused?).to be false
      expect(sprite.instance_variable_get(:@playing)).to be true
    end

    it 'stop clears the paused state' do
      sprite = cycle_sprite
      sprite.play(animation: :stones, loop: true)
      sprite.pause
      sprite.stop
      expect(sprite.paused?).to be false
      expect(sprite.instance_variable_get(:@playing)).to be false
    end
  end

  describe 'speed and time-driven advancement' do
    include_context 'sprite sheet'

    let(:sprite) do
      Sprite.new(sheet,
                 animations: { stones: %w[block_blue block_coin block_green] },
                 time: 300, add: false)
    end

    it 'defaults to 1.0' do
      expect(sprite.speed).to eq(1.0)
    end

    it 'accepts a speed: kwarg in the constructor' do
      s = Sprite.new(sheet, animations: { x: %w[block_blue block_coin] },
                     speed: 2.5, add: false)
      expect(s.speed).to eq(2.5)
    end

    it 'clamps negative speeds to 0' do
      sprite.speed = -1.0
      expect(sprite.speed).to eq(0.0)
    end

    it 'at 2.0 advances after half the frame_time' do
      sprite.speed = 2.0
      sprite.play(animation: :stones, loop: true)

      advance_ms(sprite, 100)  # 100 * 2.0 = 200 ms budget, < 300, no advance
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)

      advance_ms(sprite, 200)  # 200 * 2.0 = 400 ms, > 300, advance
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
    end

    it 'at 0.5 advances after twice the frame_time' do
      sprite.speed = 0.5
      sprite.play(animation: :stones, loop: true)

      advance_ms(sprite, 400)  # 400 * 0.5 = 200 ms, < 300, no advance
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)

      advance_ms(sprite, 700)  # 700 * 0.5 = 350 ms, > 300, advance
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
    end

    it 'at 0.0 freezes the animation while still playing' do
      sprite.speed = 0.0
      sprite.play(animation: :stones, loop: true)

      advance_ms(sprite, 10_000)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)
      expect(sprite.instance_variable_get(:@playing)).to be true
    end

    it 'skips multiple frames in one update when the delta covers several' do
      sprite.play(animation: :stones, loop: true)
      sprite.update(0.7)  # 700 ms = 2 frames of 300 ms (600), 100 ms left over
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
    end

    it 'catches up after a long frame instead of advancing only one' do
      sprite.play(animation: :stones, loop: false)
      sprite.update(0.65)  # 650 ms advances 2 frames (0 -> 2), holding before the end
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
      expect(sprite.instance_variable_get(:@playing)).to be true
    end

    it 'a high speed skips frames rather than capping at one per update' do
      sprite.speed = 4.0
      sprite.play(animation: :stones, loop: true)
      sprite.update(0.2)  # 200 ms * 4 = 800 ms budget = 2 frames (600), 200 left
      expect(sprite.instance_variable_get(:@current_frame)).to eq(2)
    end

    it 'banks the sub-frame remainder so playback does not drift' do
      sprite.play(animation: :stones, loop: true)
      sprite.update(0.2)  # 200 ms < 300, no advance, 200 ms banked
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)
      sprite.update(0.2)  # +200 = 400 banked >= 300, advance one, 100 ms left
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
      expect(sprite.instance_variable_get(:@frame_budget)).to be_within(0.01).of(100)
    end

    it 'skips the whole cycles of a runaway-fast loop and keeps the remainder' do
      sprite.speed = 1_000_000.0
      sprite.play(animation: :stones, loop: true)
      expect { sprite.update(0.1) }.not_to raise_error  # 100,000,000 ms of budget
      # 111,111 cycles of 900 ms land back on frame 0 with 100 ms in hand
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)
      expect(sprite.instance_variable_get(:@playing)).to be true
      expect(sprite.instance_variable_get(:@frame_budget)).to be_within(0.01).of(100)
    end

    it 'catches up across more than one cycle without losing time' do
      strip = "#{Ruby2D.test_spritesheets}/coin.png"
      batched = Sprite.new(strip, clip_width: 84, time: 10, animations: { blink: 0..1 }, add: false)
      batched.play(animation: :blink, loop: true)
      batched.update(0.035)
      split = Sprite.new(strip, clip_width: 84, time: 10, animations: { blink: 0..1 }, add: false)
      split.play(animation: :blink, loop: true)
      7.times { split.update(0.005) }
      expect(batched.clip_x).to eq(84)
      expect(batched.clip_x).to eq(split.clip_x)
      expect(batched.instance_variable_get(:@frame_budget)).to be_within(0.01).of(5)
      expect(split.instance_variable_get(:@frame_budget)).to be_within(0.01).of(5)
    end

    it 'catches up across cycles of an Array animation with per-frame times' do
      sprite = Sprite.new(sheet, animations: { walk: [{ name: 'block_blue', time: 10 },
                                                      { name: 'block_coin', time: 30 }] }, add: false)
      sprite.play(animation: :walk, loop: true)
      # 95 ms = two 40 ms cycles, then 10 ms onto the second frame, 5 ms left
      sprite.update(0.095)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(1)
      expect(sprite.instance_variable_get(:@frame_budget)).to be_within(0.01).of(5)
    end

    it 'still freezes on a frame with no positive time' do
      sprite = Sprite.new(sheet, animations: { walk: [{ name: 'block_blue', time: 0 }, 'block_coin'] }, add: false)
      sprite.play(animation: :walk, loop: true)
      sprite.update(10.0)
      expect(sprite.instance_variable_get(:@current_frame)).to eq(0)
      expect(sprite.playing?).to be true
    end
  end

  describe 'frame setter' do
    include_context 'sprite sheet'

    it 'reads back the frame: kwarg' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect(sprite.frame).to eq('block_blue')
    end

    it 'reports the default animation frame when no frame: was passed' do
      sprite = Sprite.new(sheet, animations: { x: ['block_blue'] }, add: false)
      expect(sprite.frame).to eq('block_blue')
    end

    it 'returns nil on a strip sprite' do
      expect(Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", add: false).frame).to be_nil
    end

    it 'follows the frame an animation shows and the one stop returns to' do
      sprite = Sprite.new(sheet, frame: 'block_blue',
                          animations: { walk: %w[block_coin block_green] }, add: false)
      sprite.play(animation: :walk)
      expect(sprite.frame).to eq('block_coin')
      tick(sprite)
      expect(sprite.frame).to eq('block_green')
      sprite.stop
      expect(sprite.frame).to eq('block_coin')
    end

    it 'is nil after a clip setter moves the pose off the named frame' do
      sprite = Sprite.new(sheet, frame: 'block_coin', add: false)
      sprite.clip_width = 64
      expect(sprite.frame).to be_nil
      sprite.frame = 'block_coin'
      sprite.clip_x = 0
      expect(sprite.frame).to be_nil
    end

    it 'is nil while an explicit rect is shown' do
      sprite = Sprite.new(sheet, frame: 'block_blue',
                          animations: { raw: [{ x: 0, y: 0, width: 8, height: 8 }] }, add: false)
      sprite.play(animation: :raw)
      expect(sprite.frame).to be_nil
    end

    it 'lets a conditional reassignment restore the static pose after playback' do
      sprite = Sprite.new(sheet, frame: 'block_blue', animations: { walk: ['block_coin'] }, add: false)
      sprite.play(animation: :walk)
      sprite.frame = 'block_blue' unless sprite.frame == 'block_blue'
      expect(sprite.clip_x).to eq(sheet['block_blue'][:x])
      expect(sprite.playing?).to be false
    end

    it 'updates the clip rect on assignment' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      target = sheet['block_coin']

      sprite.frame = 'block_coin'

      expect(sprite.frame).to eq('block_coin')
      expect(sprite.clip_x).to eq(target[:x])
      expect(sprite.clip_y).to eq(target[:y])
      expect(sprite.clip_width).to eq(target[:width])
      expect(sprite.clip_height).to eq(target[:height])
    end

    it 'stops a playing animation' do
      sprite = Sprite.new(sheet,
                          animations: { stones: %w[block_blue block_coin] },
                          add: false)
      sprite.play(animation: :stones, loop: true)
      expect(sprite.instance_variable_get(:@playing)).to be true

      sprite.frame = 'block_green'
      expect(sprite.instance_variable_get(:@playing)).to be false
    end

    it 'updates width/height to match the new frame when user did not specify them' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      sprite.frame = 'block_coin'
      target = sheet['block_coin']
      expect(sprite.width).to eq(target[:width])
      expect(sprite.height).to eq(target[:height])
    end

    it 'preserves user-specified width/height across frame changes' do
      sprite = Sprite.new(sheet, frame: 'block_blue', width: 32, height: 32, add: false)
      sprite.frame = 'block_coin'
      expect(sprite.width).to eq(32)
      expect(sprite.height).to eq(32)
    end

    it 'raises on an unknown frame name' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect { sprite.frame = 'no_such_frame' }
        .to raise_error(Ruby2D::Error, /no_such_frame/)
    end

    it 'raises on a path-based sprite (no sheet)' do
      sprite = Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", add: false)
      expect { sprite.frame = 'x' }
        .to raise_error(Ruby2D::Error, /SpriteSheet/)
    end
  end

  describe 'rotated atlas frames' do
    include_context 'sprite sheet'

    it 'raises when frame: names a rotated frame' do
      stub_frame(sheet, 'bad', { x: 0, y: 0, width: 32, height: 32, rotated: true })
      expect { Sprite.new(sheet, frame: 'bad', add: false) }
        .to raise_error(Ruby2D::Error, /rotated/)
    end

    it 'raises when an animation references a rotated frame' do
      stub_frame(sheet, 'bad', { x: 0, y: 0, width: 32, height: 32, rotated: true })
      expect do
        Sprite.new(sheet, animations: { run: %w[block_blue bad] }, add: false)
      end.to raise_error(Ruby2D::Error, /rotated/)
    end

    it 'raises when frame= is assigned a rotated frame' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      stub_frame(sheet, 'bad', { x: 0, y: 0, width: 32, height: 32, rotated: true })
      expect { sprite.frame = 'bad' }
        .to raise_error(Ruby2D::Error, /rotated/)
    end
  end

  describe 'trimmed atlas frames' do
    include_context 'sprite sheet'

    let(:trimmed_rect) do
      { x: 0, y: 0, width: 80, height: 120,
        source_width: 256, source_height: 256, trim_x: 40, trim_y: 70 }
    end

    it 'sets source size and trim ivars from a trimmed frame' do
      stub_frame(sheet, 'tr', trimmed_rect)
      sprite = Sprite.new(sheet, frame: 'tr', add: false)
      expect(sprite.instance_variable_get(:@source_width)).to eq(256)
      expect(sprite.instance_variable_get(:@source_height)).to eq(256)
      expect(sprite.instance_variable_get(:@trim_x)).to eq(40)
      expect(sprite.instance_variable_get(:@trim_y)).to eq(70)
      # Clip rect is the small packed region
      expect(sprite.clip_width).to eq(80)
      expect(sprite.clip_height).to eq(120)
    end

    it 'defaults @width/@height to the source (footprint) size, not the clip size' do
      stub_frame(sheet, 'tr', trimmed_rect)
      sprite = Sprite.new(sheet, frame: 'tr', add: false)
      expect(sprite.width).to eq(256)
      expect(sprite.height).to eq(256)
    end

    it 'preserves user-specified width/height for trimmed frames' do
      stub_frame(sheet, 'tr', trimmed_rect)
      sprite = Sprite.new(sheet, frame: 'tr', width: 100, height: 100, add: false)
      expect(sprite.width).to eq(100)
      expect(sprite.height).to eq(100)
    end

    it 'persists a runtime width=/height= override across a frame recompute' do
      stub_frame(sheet, 'tr', trimmed_rect)
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      sprite.width = 100
      sprite.height = 120
      sprite.frame = 'tr' # recomputes @width/@height from the source dimensions
      expect(sprite.width).to eq(100)
      expect(sprite.height).to eq(120)
    end

    it 'updates trim metadata when frame= is reassigned' do
      stub_frame(sheet, 'tr', trimmed_rect)
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect(sprite.instance_variable_get(:@trim_x)).to eq(0)

      sprite.frame = 'tr'
      expect(sprite.instance_variable_get(:@trim_x)).to eq(40)
      expect(sprite.instance_variable_get(:@source_width)).to eq(256)
    end

    it 'falls back to no-trim defaults for path-based sprites' do
      sprite = Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", clip_width: 84, add: false)
      expect(sprite.instance_variable_get(:@source_width)).to eq(sprite.clip_width)
      expect(sprite.instance_variable_get(:@source_height)).to eq(sprite.clip_height)
      expect(sprite.instance_variable_get(:@trim_x)).to eq(0)
      expect(sprite.instance_variable_get(:@trim_y)).to eq(0)
    end
  end

  # The clip accessors are public and unvalidated, so a degenerate (zero-size)
  # or out-of-bounds clip can be assigned after construction. The C draw path
  # treats those as a no-op rather than dividing by zero or handing SDL an
  # invalid source rect. These exercise the Ruby surface that feeds it.
  describe 'degenerate and out-of-bounds clips' do
    it 'accepts a zero-size clip without raising' do
      sprite = Sprite.new(path, add: false)
      expect { sprite.clip_width = 0 }.not_to raise_error
      expect { sprite.clip_height = 0 }.not_to raise_error
      expect(sprite.clip_width).to eq(0)
      expect(sprite.clip_height).to eq(0)
    end

    it 'accepts an out-of-bounds clip offset without raising' do
      sprite = Sprite.new(path, add: false)
      expect { sprite.clip_x = sprite.width + 100 }.not_to raise_error
      expect { sprite.clip_y = -50 }.not_to raise_error
    end
  end

  describe 'default animation and frame' do
    include_context 'sprite sheet'
    let(:strip) { "#{Ruby2D.test_spritesheets}/coin.png" } # 504x84: six 84px frames

    it 'starts a strip on its default: frame, the one stop returns to' do
      sprite = Sprite.new(strip, clip_width: 84, default: 2, add: false)
      expect(sprite.clip_x).to eq(168)
      sprite.play(loop: true)
      tick(sprite)
      sprite.stop
      expect(sprite.clip_x).to eq(168)
    end

    it 'counts strip frames from the clip origin' do
      sprite = Sprite.new(strip, clip_x: 84, clip_width: 84, add: false)
      expect(sprite.clip_x).to eq(84)
      expect(sprite.instance_variable_get(:@animations)[:default]).to eq(0..4)
      sprite.play(loop: true)
      tick(sprite)
      expect(sprite.clip_x).to eq(168)
      sprite.stop
      expect(sprite.clip_x).to eq(84)
    end

    it 'keeps an explicitly defined :default animation on a strip' do
      frames = [{ x: 84, y: 0, width: 84, height: 84, time: 100 },
                { x: 168, y: 0, width: 84, height: 84, time: 100 }]
      sprite = Sprite.new(strip, clip_width: 84, animations: { default: frames }, add: false)
      expect(sprite.clip_x).to eq(84)
      sprite.play
      sprite.update(0.1)
      expect(sprite.clip_x).to eq(168)
    end

    it 'stops to the :default animation whatever the declaration order' do
      sprite = Sprite.new(sheet, frame: 'block_blue', time: 50,
                          animations: { attack: %w[block_coin block_green], default: %w[block_blue] },
                          add: false)
      sprite.play(animation: :attack)
      tick(sprite)
      expect(sprite.clip_x).to eq(sheet['block_green'][:x])
      sprite.stop(:attack)
      expect(sprite.clip_x).to eq(sheet['block_blue'][:x])
      expect(sprite.width).to eq(sheet['block_blue'][:width])
    end

    it 'stops to the first defined animation when none is named :default' do
      sprite = Sprite.new(sheet, animations: { idle: ['block_blue'], attack: %w[block_coin] }, add: false)
      sprite.play(animation: :attack)
      sprite.stop
      expect(sprite.clip_x).to eq(sheet['block_blue'][:x])
    end

    it 'starts an atlas sprite with animations on the default animation frame' do
      sprite = Sprite.new(sheet, animations: { walk: %w[block_coin block_green] }, add: false)
      expect(sprite.clip_x).to eq(sheet['block_coin'][:x])
      expect(sprite.width).to eq(sheet['block_coin'][:width])
    end

    it 'shows an explicit frame: over the default animation' do
      sprite = Sprite.new(sheet, frame: 'block_green', animations: { default: %w[block_coin] }, add: false)
      expect(sprite.clip_x).to eq(sheet['block_green'][:x])
      sprite.stop
      expect(sprite.clip_x).to eq(sheet['block_coin'][:x])
    end

    it 'raises when default: is outside the default animation' do
      expect { Sprite.new(strip, clip_width: 84, default: 6, add: false) }
        .to raise_error(Ruby2D::Error, /`default:` frame 6 is not in animation `default`/)
      expect { Sprite.new(sheet, animations: { idle: ['block_blue'] }, default: 1, add: false) }
        .to raise_error(Ruby2D::Error, /`default:` frame 1 is not in animation `idle`/)
    end
  end

  describe 'frame geometry' do
    include_context 'sprite sheet'
    let(:strip) { "#{Ruby2D.test_spritesheets}/coin.png" }

    it 'owns its frame rects rather than sharing the caller literal' do
      rect = { x: 84, y: 0, width: 84, height: 84 }
      sprite = Sprite.new(strip, clip_width: 84, animations: { one: [rect] }, add: false)
      rect[:x] = 0
      sprite.play(animation: :one)
      expect(sprite.clip_x).to eq(84)
    end

    it 'resets the footprint when a Range animation follows an Array one' do
      sprite = Sprite.new(strip, clip_width: 84, clip_height: 84, time: 100,
                          animations: { large: [{ x: 0, y: 0, width: 168, height: 84 }], strip: 0..2 },
                          add: false)
      sprite.play(animation: :large)
      expect(sprite.width).to eq(168)
      sprite.play(animation: :strip)
      expect([sprite.width, sprite.clip_width, sprite.instance_variable_get(:@source_width)]).to eq([84, 84, 84])
    end

    it 'clears the trim when a Range animation follows a trimmed frame' do
      stub_frame(sheet, 'tr', { x: 0, y: 0, width: 80, height: 120,
                                source_width: 256, source_height: 256, trim_x: 40, trim_y: 70 })
      sprite = Sprite.new(sheet, frame: 'tr', animations: { strip: 0..1 }, add: false)
      sprite.play(animation: :strip)
      expect(sprite.instance_variable_get(:@trim_x)).to eq(0)
      expect(sprite.instance_variable_get(:@source_width)).to eq(sprite.clip_width)
    end

    it 'resumes tracking the frame when width= or height= is set to nil' do
      sprite = Sprite.new(strip, clip_width: 84, width: 168, height: 42, add: false)
      sprite.width = nil
      sprite.height = nil
      expect([sprite.width, sprite.height]).to eq([84, 84])
    end

    it 'redefines an untrimmed frame through clip_width= and clip_height=' do
      sprite = Sprite.new(strip, clip_width: 20, clip_height: 20, add: false)
      sprite.clip_width = 10
      sprite.clip_height = 10
      expect(sprite.instance_variable_get(:@source_width)).to eq(10)
      expect(sprite.instance_variable_get(:@source_height)).to eq(10)
      expect([sprite.width, sprite.height]).to eq([10, 10])
    end

    it 'keeps an explicit display size across clip_width= and clip_height=' do
      sprite = Sprite.new(strip, width: 40, height: 40, clip_width: 20, clip_height: 20, add: false)
      sprite.clip_width = 10
      sprite.clip_height = 10
      expect([sprite.width, sprite.height]).to eq([40, 40])
      expect(sprite.instance_variable_get(:@source_width)).to eq(10)
    end

    it 'advances the animation before resolving alignment in the scene hook' do
      sprite = Sprite.new(strip, clip_width: 84, x: :center, add: false)
      allow(Ruby2D::Ext).to receive(:image_draw)
      expect(sprite).to receive(:update).ordered
      expect(sprite).to receive(:_resolve_alignment).ordered
      sprite._render_scene
    end
  end

  describe 'exclusive ranges' do
    let(:strip) { "#{Ruby2D.test_spritesheets}/coin.png" }

    it 'plays up to the frame before the end' do
      sprite = Sprite.new(strip, clip_width: 84, time: 100, animations: { walk: 0...3 }, add: false)
      sprite.play(animation: :walk)
      positions = [sprite.clip_x]
      3.times { sprite.update(0.1); positions << sprite.clip_x }
      expect(positions).to eq([0, 84, 168, 168])
      expect(sprite.playing?).to be false
    end

    it 'raises when the range is empty' do
      expect { Sprite.new(strip, clip_width: 84, animations: { none: 0...0 }, add: false) }
        .to raise_error(Ruby2D::Error, /`none` has no frames/)
    end

    it 'raises on an unbounded or non-integer range' do
      [(2..), (..3), (0.0..2.0)].each do |range|
        expect { Sprite.new(strip, clip_width: 84, animations: { walk: range }, add: false) }
          .to raise_error(Ruby2D::Error, /`walk` must be a Range of strip frame indices with both ends/)
      end
    end

    it 'raises on an animation value of another type' do
      expect { Sprite.new(strip, clip_width: 84, animations: { walk: { x: 0, y: 0, width: 84, height: 84 } }, add: false) }
        .to raise_error(Ruby2D::Error, /`walk` must be a Range of strip frames, an Array of frames, or a frame name/)
      expect { Sprite.new(strip, clip_width: 84, animations: { walk: 5 }, add: false) }
        .to raise_error(Ruby2D::Error, /`walk` must be/)
    end
  end

  describe 'flip while playing' do
    let(:strip) { "#{Ruby2D.test_spritesheets}/coin.png" }
    let(:sprite) { Sprite.new(strip, clip_width: 84, time: 100, animations: { walk: 0..3 }, add: false) }

    it 'play with a new flip keeps the frame, the timing, and the completion block' do
      completed = 0
      sprite.play(animation: :walk) { completed += 1 }
      sprite.update(0.1)
      sprite.update(0.05)
      sprite.play(animation: :walk, flip: :horizontal)
      expect(sprite.flip).to eq(:horizontal)
      expect(sprite.clip_x).to eq(84)
      5.times { sprite.update(0.05) }
      expect(sprite.clip_x).to eq(252)
      expect(sprite.playing?).to be false
      expect(completed).to eq(1)
    end

    it 'play with a new flip keeps looping when loop: is omitted' do
      sprite.play(animation: :walk, loop: true)
      sprite.play(animation: :walk, flip: :horizontal)
      expect(sprite.looping?).to be true
    end

    it 'play with flip: nil clears the flip on the already-playing path' do
      sprite.play(animation: :walk, loop: true, flip: :horizontal)
      sprite.update(0.1)
      sprite.play(animation: :walk, loop: true, flip: nil)
      expect(sprite.flip).to be_nil
      expect(sprite.clip_x).to eq(84)
      expect(sprite.looping?).to be true
    end

    it 'play without flip: leaves the flip alone on the already-playing path' do
      sprite.play(animation: :walk, flip: :horizontal)
      sprite.play(animation: :walk)
      expect(sprite.flip).to eq(:horizontal)
    end

    it 'play without flip: clears it when the animation restarts' do
      sprite.play(animation: :walk, flip: :horizontal)
      sprite.stop
      sprite.play(animation: :walk)
      expect(sprite.flip).to be_nil
    end
  end

  describe 'drawn by the scene' do
    let(:strip) { "#{Ruby2D.test_spritesheets}/coin.png" }
    let(:sprite) { Sprite.new(strip, clip_width: 84, time: 100, animations: { walk: 0..3 }, add: false) }

    before { allow(Ruby2D::Ext).to receive(:image_draw) }

    # Draw the sprite as the scene would, with the window's clock at `clock`
    # seconds.
    def draw(sprite, frame: nil, clock:)
      allow(Ruby2D::Window).to receive(:_clock).and_return(clock)
      sprite._render_scene
    end

    it 'gives the first frame after play its full duration' do
      sprite.play(animation: :walk, loop: true)
      draw(sprite, frame: 1, clock: 5.0)
      expect(sprite.clip_x).to eq(0)
      draw(sprite, frame: 2, clock: 5.05)
      expect(sprite.clip_x).to eq(0)
      draw(sprite, frame: 3, clock: 5.15)
      expect(sprite.clip_x).to eq(84)
    end

    it 'advances by the clock since its previous draw, drawn frames only counted' do
      sprite.play(animation: :walk, loop: true)
      draw(sprite, frame: 1, clock: 5.0)
      draw(sprite, frame: 2, clock: 5.2) # skipped ticks in between: their time counts
      expect(sprite.clip_x).to eq(168)
    end

    it 'ignores the time that passed before play' do
      allow(Ruby2D::Window).to receive(:_clock).and_return(9.0)
      sprite.play(animation: :walk)
      draw(sprite, frame: 1, clock: 9.0)
      expect(sprite.clip_x).to eq(0)
      expect(sprite.playing?).to be true
    end

    it 'keeps time while hidden and shows where its animation has reached' do
      sprite.play(animation: :walk, loop: true)
      draw(sprite, frame: 1, clock: 5.0)
      sprite.hide
      draw(sprite, frame: 2, clock: 5.15)
      expect(sprite.clip_x).to eq(0)
      sprite.show
      draw(sprite, frame: 3, clock: 5.25)
      expect(sprite.clip_x).to eq(168)
    end

    it 'keeps advancing while blinking' do
      sprite.play(animation: :walk)
      6.times do |i|
        sprite.visible = i.even?
        draw(sprite, clock: 5.0 + i * 0.1)
      end
      expect(sprite.clip_x).to eq(252)
      expect(sprite.playing?).to be false
    end

    it 'skips the label of a Button it is the visual of when its completion block hides it' do
      allow(Ruby2D::Ext).to receive(:text_draw)
      Button.new(sprite, label: 'go')
      sprite.play(animation: :walk) { sprite.hide }
      draw(sprite, clock: 5.0)
      expect(Ruby2D::Ext).not_to receive(:text_draw)
      draw(sprite, clock: 5.5)
    end

    it 'advances once when drawn twice in one frame' do
      sprite.play(animation: :walk, loop: true)
      draw(sprite, frame: 1, clock: 5.0)
      draw(sprite, frame: 2, clock: 5.15)
      draw(sprite, frame: 2, clock: 5.15)
      expect(sprite.clip_x).to eq(84)
    end

    it 'is not drawn while hidden' do
      sprite.play(animation: :walk, loop: true)
      draw(sprite, frame: 1, clock: 5.0)
      sprite.hide
      expect(Ruby2D::Ext).not_to receive(:image_draw)
      draw(sprite, frame: 2, clock: 5.3)
    end

    it 'is not drawn when its completion block hides it' do
      sprite.play(animation: :walk) { sprite.hide }
      draw(sprite, frame: 1, clock: 5.0)
      expect(Ruby2D::Ext).not_to receive(:image_draw)
      draw(sprite, frame: 2, clock: 5.4)
      expect(sprite.visible?).to be false
      expect(sprite.playing?).to be false
    end

    it 'is drawn when its completion block leaves it visible' do
      sprite.play(animation: :walk)
      draw(sprite, frame: 1, clock: 5.0)
      expect(Ruby2D::Ext).to receive(:image_draw).with(sprite)
      draw(sprite, frame: 2, clock: 5.4)
    end

    it 'advances a hand-driven no-argument update by the clock since the last one' do
      sprite.play(animation: :walk, loop: true)
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.0, 5.06, 5.06, 5.12)
      4.times { sprite.update }
      expect(sprite.clip_x).to eq(84)
    end
  end
end
