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

    it 'raises a clear error when playing an empty animation' do
      sprite = Sprite.new(sheet, animations: { empty: [] }, add: false)
      expect { sprite.play(animation: :empty) }
        .to raise_error(Ruby2D::Error, /no frames/)
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

    it 'caps a runaway-fast loop at one cycle per update instead of spinning' do
      sprite.speed = 1_000_000.0
      sprite.play(animation: :stones, loop: true)
      expect { sprite.update(0.1) }.not_to raise_error  # enormous budget
      expect(sprite.instance_variable_get(:@current_frame)).to be_between(0, 2)
      expect(sprite.instance_variable_get(:@playing)).to be true
      # The leftover budget was dropped, not left to grow without bound
      expect(sprite.instance_variable_get(:@frame_budget)).to eq(0.0)
    end
  end

  describe 'frame setter' do
    include_context 'sprite sheet'

    it 'reads back the frame: kwarg' do
      sprite = Sprite.new(sheet, frame: 'block_blue', add: false)
      expect(sprite.frame).to eq('block_blue')
    end

    it 'returns nil when no frame: was passed' do
      sprite = Sprite.new(sheet, animations: { x: ['block_blue'] }, add: false)
      expect(sprite.frame).to be_nil
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
end
