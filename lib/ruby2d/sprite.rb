# Ruby2D::Sprite

module Ruby2D
  # An animated sprite from a single image, a horizontal strip sprite sheet, or
  # a SpriteSheet (texture atlas).
  class Sprite < Image
    attr_reader :flip, :sheet, :speed, :frame, :clip_x, :clip_y, :clip_width, :clip_height

    # Sentinel default for `update`'s `dt`. Lets the no-arg scene-graph call defer
    # resolving the window's render delta until after the `@playing` guard, so a
    # paused or static sprite never pays for it. A frozen unique object, so an
    # explicit `update(nil)` is still distinct from the default and behaves as
    # before.
    UPDATE_DT_UNSET = Object.new.freeze
    private_constant :UPDATE_DT_UNSET

    # Sentinel default for `play`'s `flip:`, so an omitted flip is distinct
    # from an explicit `flip: nil`, which clears the flip.
    FLIP_UNSET = Object.new.freeze
    private_constant :FLIP_UNSET

    # Create a sprite. `source` can be either an image path or a SpriteSheet
    # instance. When given a SpriteSheet, animations may reference frames by
    # name (strings or `{ name:, time: }` hashes) and `frame:` selects a
    # single static frame.
    def initialize(source, width: nil, height: nil,
                   x: 0, y: 0, z: 0, rotate: 0, rx: nil, ry: nil,
                   tint: nil, opacity: nil,
                   loop: false, time: 300, speed: 1.0,
                   animations: nil, default: 0,
                   frame: nil,
                   clip_x: 0, clip_y: 0, clip_width: nil, clip_height: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil,
                   scale_mode: nil)
      @sheet = source.is_a?(SpriteSheet) ? source : nil

      if @sheet
        super(nil, x: x, y: y, z: z, rotate: rotate, rx: rx, ry: ry,
              tint: tint, opacity: opacity, add: false,
              padding: padding, padding_top: padding_top, padding_right: padding_right,
              padding_bottom: padding_bottom, padding_left: padding_left,
              scale_mode: scale_mode, _share_from: @sheet.texture)
      else
        super(source, x: x, y: y, z: z, rotate: rotate, rx: rx, ry: ry,
              tint: tint, opacity: opacity, add: false,
              padding: padding, padding_top: padding_top, padding_right: padding_right,
              padding_bottom: padding_bottom, padding_left: padding_left,
              scale_mode: scale_mode)
      end

      # The sheet rect (if any) that sizes the clip and, unless an animation
      # takes over below, is the pose the sprite starts on.
      sheet_rect = nil
      static_name = nil

      if frame
        raise Error, '`frame:` requires a SpriteSheet source' unless @sheet

        static_name = frame.to_s
        sheet_rect  = lookup_sheet_frame(static_name)
        clip_x      = sheet_rect[:x]
        clip_y      = sheet_rect[:y]
        clip_width  = sheet_rect[:width]
        clip_height = sheet_rect[:height]
      end

      @img_width  = @orig_width
      @img_height = @orig_height

      @flip = nil

      @loop = loop
      @frame_time = time
      self.speed = speed
      @animations = normalize_animations(animations || {})
      @current_frame = default

      # When a sheet is in use and no explicit clip / frame was given, fall back
      # to the first frame in the sheet so the sprite shows something useful.
      if @sheet && !frame && clip_width.nil? && clip_height.nil?
        first_name = @sheet.frame_names.first
        first = first_name && lookup_sheet_frame(first_name)
        if first
          sheet_rect  = first
          static_name = first_name
          clip_x      = first[:x]
          clip_y      = first[:y]
          clip_width  = first[:width]
          clip_height = first[:height]
        end
      end

      @clip_x = clip_x
      @clip_y = clip_y
      @clip_width  = (clip_width  || @img_width ).to_i
      @clip_height = (clip_height || @img_height).to_i
      @clip_width  = @img_width  if @clip_width  <= 0
      @clip_height = @img_height if @clip_height <= 0

      # Track user-provided display dimensions so animations can update
      # @width/@height to match the source (footprint) dimensions when no
      # explicit size was given.
      @user_width  = width
      @user_height = height

      @clipped = true

      setup_animation

      # The starting pose: an explicit `frame:` wins; otherwise the default
      # animation's `default:` frame, so a sprite shows the frame `stop` would
      # return it to; otherwise the sheet's first frame or the plain clip.
      if !frame && @defaults[:animation]
        @playing_animation = @defaults[:animation]
        set_frame
      elsif sheet_rect
        apply_frame(sheet_rect, static_name)
      else
        apply_rect(@clip_x, @clip_y, @clip_width, @clip_height)
      end

      @visible = visible
      self.add if add
    end

    # A SpriteSheet-backed sprite shares one backing texture with every other
    # sprite cut from the same sheet. Re-rasterizing it (Image#resize!) would
    # silently corrupt all of them and invalidate the sheet's frame coordinates,
    # so refuse it. Path/strip-backed sprites own their texture and resize fine.
    def resize!(width = @width, height = @height)
      if @sheet
        raise Error,
              'Cannot resize! a SpriteSheet-backed sprite: its texture is shared ' \
              'by every sprite cut from the same sheet. Use a standalone Image, or ' \
              'set width/height to change only this sprite\'s display size.'
      end

      super
    end

    # Set the displayed width. Like the `width:` constructor option, this persists
    # across animation frames (stored as the user override). A sprite without an
    # explicit size tracks each frame's source dimensions; set to nil to resume
    # that source-tracking, from the current frame on. Overrides Image's plain
    # `attr_accessor`, which wrote `@width` directly and was silently reset by
    # the next animation tick.
    def width=(w)
      @user_width = w
      @width = w || @source_width
    end

    # Set the displayed height. See `width=` — persists across frames; nil resumes
    # source-tracking.
    def height=(h)
      @user_height = h
      @height = h || @source_height
    end

    # Set the clip origin. The pose is no longer a named atlas frame.
    def clip_x=(x)
      @clip_x = x
      @frame = nil
    end

    def clip_y=(y)
      @clip_y = y
      @frame = nil
    end

    # Set the clip width. The frame becomes an untrimmed region of that width:
    # its source footprint follows, so the frame still fills the display width
    # (which tracks it unless `width` was given), instead of drawing scaled
    # against the previous frame's footprint. Same for `clip_height=`.
    def clip_width=(w)
      @clip_width = w
      @source_width = w
      @trim_x = 0
      @width = @user_width || w
      @frame = nil
    end

    def clip_height=(h)
      @clip_height = h
      @source_height = h
      @trim_y = 0
      @height = @user_height || h
      @frame = nil
    end

    # Whether the current animation loops
    def looping?
      @loop
    end

    # Set whether the current animation loops, mid-play, without restarting it
    # (unlike re-calling `play`). Takes effect at the next loop boundary while
    # the animation is still playing: turning it off lets a cycling animation
    # finish — and fire any completion block — when it next reaches the last
    # frame; turning it on keeps it cycling. It does not resume an animation
    # that has already finished and stopped — call `play` to restart that.
    def loop=(value)
      @loop = value ? true : false
    end

    # Start playing an animation. Pass `loop:` to override the sprite's default
    # loop setting and a block to run when a non-looping animation finishes.
    def play(animation: :default, loop: nil, flip: FLIP_UNSET, &done_proc)
      anim_name = animation || :default

      if @playing && anim_name == @playing_animation
        # Same animation already running: don't restart it — that would jump
        # back to frame 0 — but still honor an explicitly-passed `loop:`,
        # `flip:`, or completion block so callers can adjust them mid-play.
        # Anything left unset is preserved, so a per-frame `play(:state)` call
        # stays a safe no-op and turning a character around keeps its stride.
        @loop = loop ? true : false unless loop.nil?
        @done_proc = done_proc if done_proc
        self.flip = flip unless flip.equal?(FLIP_UNSET)
      else
        # Validate before mutating any state, so a typo'd animation fails
        # clearly here instead of crashing later in `update`.
        raise Error, "Animation `#{anim_name}` is not defined for this sprite" if @animations[anim_name].nil?

        @playing = true
        @paused = false
        @playing_animation = anim_name
        @done_proc = done_proc

        self.flip = flip.equal?(FLIP_UNSET) ? nil : flip
        reset_playing_animation

        loop = @defaults[:loop] if loop.nil?
        @loop = loop ? true : false

        set_frame
        @frame_budget = 0.0   # first frame gets its full duration
        @clock = nil
      end
      self
    end

    # Pause the current animation on its current frame. Idempotent and
    # only meaningful while an animation is playing — calling it on an
    # idle sprite is a no-op.
    def pause
      return self unless @playing

      @playing = false
      @paused = true
      self
    end

    # Resume the animation paused by `pause`, picking up at the current
    # frame. The frame budget is reset so the first frame after resume
    # gets its full duration.
    def resume
      return self unless @paused

      @paused = false
      @playing = true
      @frame_budget = 0.0
      @clock = nil
      self
    end

    # Whether the sprite is currently paused
    def paused?
      @paused == true
    end

    # Whether an animation is actively playing. False when idle, paused,
    # or held on the last frame of a finished non-looping animation.
    def playing?
      @playing == true
    end

    # Animation rate multiplier — `1.0` runs at the configured `time:`
    # per frame, `2.0` plays twice as fast, `0.5` half-speed. Negative
    # values clamp to 0 (frozen). Reverse playback is not supported.
    def speed=(value)
      v = value.to_f
      @speed = v < 0 ? 0.0 : v
    end

    # Set the static frame by name (atlas-backed sprites only). Stops
    # any playing animation, since asserting a static pose is
    # incompatible with continuing a sequence — call `play` afterwards
    # to resume animating.
    def frame=(name)
      raise Error, '`frame=` requires a SpriteSheet source' unless @sheet

      name = name.to_s
      rect = lookup_sheet_frame(name)

      @playing = false
      @paused = false
      @done_proc = nil

      apply_frame(rect, name)
    end

    # Stop the current animation and set to the default frame
    def stop(animation = nil)
      return unless !animation || animation == @playing_animation

      @playing = false
      @paused = false
      @playing_animation = @defaults[:animation]
      @current_frame = @defaults[:frame]
      set_frame
    end

    # Set the flip direction: `:horizontal`, `:vertical`, `:both`, or `nil`
    def flip=(direction)
      if (!@width || !@height) && direction
        raise Error, "Sprite width/height required to flip (animation `:#{@playing_animation}`, image `#{@path}`)"
      end

      @flip = direction
    end

    # Advance the animation by one frame of real time and update the clip rect.
    # Called with no arguments from the scene-graph loop, where `dt` is what
    # the window's clock (`Window._clock`, the sum of the engine's shared
    # per-tick deltas — the same clock an `update do |dt|` block sees) has
    # advanced since this sprite's previous no-argument update, so a tick that
    # skips drawing in `:on_demand` mode delays the drawing, not the animation,
    # a hidden sprite keeps time and shows where its animation has reached,
    # and a second draw in the same tick advances nothing. `play` and `resume`
    # start the count afresh, so time that passed before them matters to
    # nothing. Driving every sprite off that one clock
    # (rather than each polling its own) keeps them in lockstep, lets the
    # engine clamp stalls once, and makes `update(dt)` directly testable. Pass
    # an explicit `dt` (in seconds) to drive the animation by hand.
    def update(dt = UPDATE_DT_UNSET)
      return unless @playing

      # Read the clock only now that we know the sprite is playing — the
      # no-arg scene-graph call hits this every frame per sprite.
      if dt.equal?(UPDATE_DT_UNSET)
        now = Window._clock
        dt = @clock ? now - @clock : 0.0
        @clock = now
      end

      # Bank the elapsed time, scaled by `@speed` (0.0 freezes, 2.0 is double
      # speed), then spend it one whole frame at a time. Looping here — rather
      # than a single step per call — lets a high `speed` skip frames and a long
      # frame catch up, instead of capping at one frame per tick. Each frame is
      # charged its own `time:`, and the unspent remainder stays banked so
      # playback doesn't slowly drift. The budget is in milliseconds.
      @frame_budget += dt * @speed * 1000.0

      # A looping animation lands back on the current frame after every whole
      # cycle, so a budget spanning several — a long stall, an absurd `speed`,
      # frames far shorter than the tick — skips them in one step and walks
      # only the remainder below, which keeps the loop bounded by one cycle
      # without dropping time. `@cycle_time` is nil when a frame has no
      # positive duration; playback freezes on that frame anyway.
      @frame_budget %= @cycle_time if @loop && @cycle_time && @frame_budget >= @cycle_time

      finished = false

      while @playing
        ft = @frame_time || @defaults[:frame_time]
        break if ft.nil? || ft <= 0 || @frame_budget < ft

        @frame_budget -= ft
        @current_frame += 1

        if @current_frame > @last_frame
          if @loop
            @current_frame = @first_frame
          else
            # Hold on the last frame and stop advancing. The user can call
            # `stop` (or `play` something else) to leave the pose. This lets a
            # death animation linger on its corpse pose, a jump animation hold
            # mid-air, an attack hold its follow-through, etc.
            @current_frame = @last_frame
            @playing = false
            finished = true
          end
        end
        set_frame   # refresh the clip rect and pick up the next frame's `time:`
      end

      # Fire the completion block last — after the bookkeeping above — so a
      # `play` chained inside it has the final say. Clear it first so the chained
      # play can install its own block without us seeing a stale reference.
      return unless finished && @done_proc

      kept_done_proc = @done_proc
      @done_proc = nil
      kept_done_proc.call
    end

    # Render the sprite. With no arguments it draws the same frame the scene
    # graph does (delegating to `_render_scene`) — advancing the animation and
    # drawing the current frame. Called with overrides for one-shot rendering
    # inside a render block (one-shot does not advance the animation).
    def render(x: nil, y: nil, width: nil, height: nil, rotate: nil,
               clip_x: nil, clip_y: nil, clip_width: nil, clip_height: nil,
               tint: nil, opacity: nil)
      if x.nil? && y.nil? && width.nil? && height.nil? && rotate.nil? &&
         clip_x.nil? && clip_y.nil? && clip_width.nil? && clip_height.nil? &&
         tint.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      saved_x, saved_y = @x, @y
      saved_width, saved_height = @width, @height
      saved_rotate = @rotate
      saved_clip_x, saved_clip_y = @clip_x, @clip_y
      saved_clip_width, saved_clip_height = @clip_width, @clip_height
      saved_source_w, saved_source_h = @source_width, @source_height
      saved_trim_x, saved_trim_y = @trim_x, @trim_y
      saved_color = @color

      @x = x if x
      @y = y if y
      @width = width if width
      @height = height if height
      @rotate = rotate if rotate
      @clip_x = clip_x if clip_x
      @clip_y = clip_y if clip_y
      @clip_width = clip_width if clip_width
      @clip_height = clip_height if clip_height

      # Override draws use no trim — the caller is being explicit about
      # source rect and display size, so collapse the trim math to the
      # straightforward `draw clip into (x, y, width, height)` case.
      @source_width  = @clip_width
      @source_height = @clip_height
      @trim_x = 0
      @trim_y = 0

      if tint || opacity
        @color = tint ? Color.new(tint) : Color.new(saved_color)
        @color.opacity = opacity if opacity
      end

      begin
        Ext.image_draw(self)
      ensure
        @x, @y = saved_x, saved_y
        @width, @height = saved_width, saved_height
        @rotate = saved_rotate
        @clip_x, @clip_y = saved_clip_x, saved_clip_y
        @clip_width, @clip_height = saved_clip_width, saved_clip_height
        @source_width, @source_height = saved_source_w, saved_source_h
        @trim_x, @trim_y = saved_trim_x, saved_trim_y
        @color = saved_color
      end
    end

    private

    # Scene-graph draw hook (see Renderable#_render_scene): advance the
    # animation and draw the current frame, minus `render`'s keyword handling
    # — a zero-arg call into the 11-keyword `render` still pays ~5µs of
    # keyword setup on wasm mruby, half a millisecond per frame at 100 sprites.
    # The animation advances first: a new frame can change the sprite's size,
    # which alignment positions against, and its completion block can hide
    # the sprite, which the scene loop checked before calling here. A hidden
    # sprite is not drawn, by the scene or by a bare `render`; its animation
    # keeps time (see `update`), so it is drawn where it has reached once
    # shown.
    def _render_scene
      return unless @visible

      update
      return unless @visible

      _resolve_alignment
      Ext.image_draw(self)
    end
    public :_render_scene

    # Apply the current frame of the playing animation: the clip rect, the
    # frame's footprint and trim, the display size, and its duration.
    def set_frame
      frames = @animations[@playing_animation]
      case frames
      when Range
        # Frames of a strip sit side by side from the clip origin given at
        # construction, each `clip_width` wide.
        step = @defaults[:clip_width]
        apply_rect(@defaults[:clip_x] + @current_frame * step, @defaults[:clip_y],
                   step, @defaults[:clip_height])
        # Range frames carry no per-frame `time:`, so reset to the default
        # rather than inheriting a leftover value from a prior Array animation.
        @frame_time = @defaults[:frame_time]
      when Array
        rect = frames[@current_frame]
        # Defensive: leave the pose in place rather than crash on an index
        # past the end.
        return if rect.nil?

        apply_frame(rect)
        @frame_time = rect[:time] || @defaults[:frame_time]
      end
    end

    # Reset the playing animation to the first frame
    def reset_playing_animation
      frames = @animations[@playing_animation]
      case frames
      # When animation is a range, play through frames horizontally
      when Range
        @first_frame   = frames.begin
        @current_frame = frames.begin
        @last_frame    = frames.end
        @frame_time    = @defaults[:frame_time]
        count = @last_frame - @first_frame + 1
        @cycle_time = @frame_time && @frame_time > 0 ? count * @frame_time : nil
      # When array...
      when Array
        @first_frame   = 0
        @current_frame = 0
        @last_frame    = frames.length - 1
        @cycle_time = 0.0
        frames.each do |rect|
          ft = rect[:time] || @defaults[:frame_time]
          if ft.nil? || ft <= 0
            @cycle_time = nil
            break
          end
          @cycle_time += ft
        end
      end
    end

    # Apply a frame rect — `{ x:, y:, width:, height: }` plus optional
    # `source_width`, `source_height`, `trim_x`, `trim_y`, and `name` — as the
    # sprite's current pose.
    def apply_frame(rect, name = rect[:name])
      apply_rect(rect[:x] || @defaults[:clip_x], rect[:y] || @defaults[:clip_y],
                 rect[:width] || @defaults[:clip_width], rect[:height] || @defaults[:clip_height],
                 rect[:source_width], rect[:source_height], rect[:trim_x], rect[:trim_y], name)
    end

    # The one place a pose is written: the clip rect, the footprint the clip
    # is drawn into (the clip itself when untrimmed), where the clip sits in
    # it, the display size — the user's override or the footprint — and the
    # atlas frame name, nil for a strip frame or an explicit rect. Everything
    # that selects a frame (construction, animation steps, `stop`, `frame=`,
    # `resize!`) goes through here so no field can go stale.
    def apply_rect(x, y, width, height, source_width = nil, source_height = nil,
                   trim_x = nil, trim_y = nil, name = nil)
      @clip_x      = x
      @clip_y      = y
      @clip_width  = width
      @clip_height = height
      @source_width  = source_width  || width
      @source_height = source_height || height
      @trim_x = trim_x || 0
      @trim_y = trim_y || 0
      @width  = @user_width  || @source_width
      @height = @user_height || @source_height
      @frame  = name
    end

    # initialize animation, called by constructor
    def setup_animation
      @frame_budget = 0.0
      @playing = false
      @paused = false
      @last_frame = 0
      @cycle_time = nil
      @done_proc = nil
      @clock = nil

      # Generate `:default` for path-based sprites where the source is a
      # horizontal strip from the clip origin, unless the user defined one.
      # Atlas sources have arbitrary 2D layouts, so we leave `:default` to the
      # user.
      unless @sheet || @animations.key?(:default)
        count = ((@img_width - @clip_x) / @clip_width).to_i
        count = 1 if count < 1
        @animations[:default] = 0..(count - 1)
      end

      # The animation `stop` returns to and construction starts on: `:default`
      # when defined, else the first one defined, else none.
      default_anim = if @animations.key?(:default) then :default
                     elsif @animations.empty? then nil
                     else @animations.first[0]
                     end

      @defaults = {
        animation: default_anim,
        frame: @current_frame,
        frame_time: @frame_time,
        clip_x: @clip_x,
        clip_y: @clip_y,
        clip_width: @clip_width,
        clip_height: @clip_height,
        loop: @loop
      }

      frames = @animations[default_anim]
      return if frames.nil? || frame_index?(frames, @current_frame)

      raise Error, "`default:` frame #{@current_frame.inspect} is not in animation `#{default_anim}` (#{describe_frames(frames)})"
    end

    # Whether `index` selects a frame of `frames`: a strip index for a Range,
    # a position for an Array.
    def frame_index?(frames, index)
      return false unless index.is_a?(Integer)

      if frames.is_a?(Range)
        index >= frames.begin && index <= frames.end
      else
        index >= 0 && index < frames.length
      end
    end

    def describe_frames(frames)
      frames.is_a?(Range) ? "frames #{frames}" : "#{frames.length} frames"
    end

    # Resolve frame-name strings against the SpriteSheet so the rest of the
    # class only has to deal with `{x:,y:,width:,height:[,time:]}` rects and
    # numeric Ranges — the same shapes the legacy path-based API uses. An
    # exclusive Range becomes the inclusive one it stands for, and anything
    # else — an unbounded Range, an animation with no frames, a value of
    # another type — is rejected here rather than when it is played.
    def normalize_animations(anims)
      result = {}
      anims.each do |name, frames|
        frames = case frames
                 when Range  then normalize_range(name, frames)
                 when Array  then frames.map { |f| normalize_frame(f) }
                 when String then [normalize_frame(frames)]
                 else
                   raise Error, "Animation `#{name}` must be a Range of strip frames, an Array of frames, or a frame name, got #{frames.inspect}"
                 end
        raise Error, "Animation `#{name}` has no frames" if frames.is_a?(Array) && frames.empty?

        result[name] = frames
      end
      result
    end

    def normalize_range(name, range)
      first = range.begin
      last  = range.end
      unless first.is_a?(Integer) && last.is_a?(Integer)
        raise Error, "Animation `#{name}` must be a Range of strip frame indices with both ends, got #{range.inspect}"
      end

      last -= 1 if range.exclude_end?
      raise Error, "Animation `#{name}` has no frames" if first > last

      first..last
    end

    def normalize_frame(spec)
      if spec.is_a?(String)
        rect = lookup_sheet_frame(spec).dup
        rect[:name] = spec
        rect
      elsif spec.is_a?(Hash)
        name = spec[:name] || spec['name']
        if name
          rect = lookup_sheet_frame(name).dup
          rect[:name] = name.to_s
          time = spec[:time] || spec['time']
          rect[:time] = time if time
          rect
        else
          # The sprite owns its rects: `resize!` scales them in place, and a
          # caller may build several sprites from one literal.
          spec.dup
        end
      else
        raise Error, "Invalid animation frame spec: #{spec.inspect}"
      end
    end

    def lookup_sheet_frame(name)
      raise Error, "Frame `#{name}` requires a SpriteSheet source" unless @sheet

      rect = @sheet.frame(name) ||
        raise(Error, "Frame `#{name}` not found in sprite sheet `#{@sheet.path}`")

      if rect[:rotated]
        raise Error,
              "Frame `#{name}` in sprite sheet `#{@sheet.path}` is packed rotated; " \
              'rotated atlas frames are not yet supported. Repack the atlas without rotation.'
      end

      rect
    end
  end
end
