# Ruby2D::Sprite

module Ruby2D
  # An animated sprite from a single image, a horizontal strip sprite sheet, or
  # a SpriteSheet (texture atlas).
  class Sprite < Image
    attr_reader :flip, :sheet, :speed, :frame
    attr_accessor :clip_x, :clip_y, :clip_width, :clip_height

    # Sentinel default for `update`'s `dt`. Lets the no-arg scene-graph call defer
    # resolving `Window.delta_time` until after the `@playing` guard, so a paused
    # or static sprite never pays for it. A frozen unique object, so an explicit
    # `update(nil)` is still distinct from the default and behaves as before.
    UPDATE_DT_UNSET = Object.new.freeze
    private_constant :UPDATE_DT_UNSET

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

      # Stash the resolved sheet rect (if any) so trim metadata can be
      # applied after @clip_width/@clip_height get their final values.
      sheet_rect = nil

      if frame
        raise Error, '`frame:` requires a SpriteSheet source' unless @sheet

        sheet_rect  = lookup_sheet_frame(frame.to_s)
        clip_x      = sheet_rect[:x]
        clip_y      = sheet_rect[:y]
        clip_width  = sheet_rect[:width]
        clip_height = sheet_rect[:height]
        @frame      = frame.to_s
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
        first = first_sheet_rect
        if first
          sheet_rect  = first
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

      # Trim metadata. For atlas frames it can come from the sheet rect;
      # for path-based sprites and untrimmed atlas frames it falls back
      # to the no-trim defaults (source = clip, trim = 0). With those
      # defaults, the C draw path's trim math collapses to today's
      # untrimmed behavior.
      @source_width  = (sheet_rect && sheet_rect[:source_width])  || @clip_width
      @source_height = (sheet_rect && sheet_rect[:source_height]) || @clip_height
      @trim_x = (sheet_rect && sheet_rect[:trim_x]) || 0
      @trim_y = (sheet_rect && sheet_rect[:trim_y]) || 0

      # Track user-provided display dimensions so animations can update
      # @width/@height to match the source (footprint) dimensions when no
      # explicit size was given.
      @user_width  = width
      @user_height = height
      @width  = width  || @source_width
      @height = height || @source_height

      @clipped = true

      setup_animation

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
    # that source-tracking. Overrides Image's plain `attr_accessor`, which wrote
    # `@width` directly and was silently reset by the next animation tick.
    def width=(w)
      @user_width = w
      @width = w
    end

    # Set the displayed height. See `width=` — persists across frames; nil resumes
    # source-tracking.
    def height=(h)
      @user_height = h
      @height = h
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
    def play(animation: :default, loop: nil, flip: nil, &done_proc)
      anim_name = animation || :default

      if @playing && anim_name == @playing_animation && flip == @flip
        # Same animation already running (same flip): don't restart it — that
        # would jump back to frame 0 — but still honor an explicitly-passed
        # `loop:` or completion block so callers can adjust them mid-play.
        # Anything left unset is preserved, so a per-frame `play(:state)` call
        # stays a safe no-op.
        @loop = loop ? true : false unless loop.nil?
        @done_proc = done_proc if done_proc
      else
        frames = @animations[anim_name]
        # Validate up front, before mutating any state, so a typo'd or empty
        # animation fails clearly here instead of crashing later in `update`.
        raise Error, "Animation `#{anim_name}` is not defined for this sprite" if frames.nil?
        raise Error, "Animation `#{anim_name}` has no frames" if frames.is_a?(Array) && frames.empty?

        @playing = true
        @paused = false
        @playing_animation = anim_name
        @done_proc = done_proc

        self.flip = flip
        reset_playing_animation

        loop = @defaults[:loop] if loop.nil?
        @loop = loop ? true : false

        set_frame
        @frame_budget = 0.0   # first frame gets its full duration
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

      rect = lookup_sheet_frame(name.to_s)

      @playing = false
      @paused = false
      @done_proc = nil

      @clip_x      = rect[:x]
      @clip_y      = rect[:y]
      @clip_width  = rect[:width]
      @clip_height = rect[:height]
      @source_width  = rect[:source_width]  || @clip_width
      @source_height = rect[:source_height] || @clip_height
      @trim_x = rect[:trim_x] || 0
      @trim_y = rect[:trim_y] || 0
      @width  = @user_width  || @source_width
      @height = @user_height || @source_height
      @frame  = name.to_s
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
    # Called with no arguments from the scene-graph loop, where `dt` defaults to
    # the engine's shared frame delta (`Window.delta_time`) — the same value an
    # `update do |dt|` block receives. Driving every sprite off that one clock
    # (rather than each polling its own) keeps them in lockstep, lets the engine
    # clamp stalls once, and makes `update(dt)` directly testable. Pass an
    # explicit `dt` (in seconds) to drive the animation by hand.
    def update(dt = UPDATE_DT_UNSET)
      return unless @playing

      # Resolve the shared frame delta only now that we know the sprite is
      # playing — the no-arg scene-graph call hits this every frame per sprite.
      dt = Window.delta_time if dt.equal?(UPDATE_DT_UNSET)

      # Bank the elapsed time, scaled by `@speed` (0.0 freezes, 2.0 is double
      # speed), then spend it one whole frame at a time. Looping here — rather
      # than a single step per call — lets a high `speed` skip frames and a long
      # frame catch up, instead of capping at one frame per tick. Each frame is
      # charged its own `time:`, and the unspent remainder stays banked so
      # playback doesn't slowly drift. The budget is in milliseconds.
      @frame_budget += dt * @speed * 1000.0

      cycle    = @last_frame - @first_frame + 1   # frames in one full loop
      steps    = 0
      finished = false

      while @playing && steps < cycle
        ft = @frame_time || @defaults[:frame_time]
        break if ft.nil? || ft <= 0 || @frame_budget < ft

        @frame_budget -= ft
        steps += 1
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

      # Cap a runaway-fast loop (an absurd `speed`) at one cycle per update so it
      # can't spin; drop the unspent budget rather than letting it grow unbounded.
      @frame_budget = 0.0 if @playing && steps == cycle && @frame_budget >= (@frame_time || @defaults[:frame_time])

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
    def _render_scene
      _resolve_alignment
      update
      Ext.image_draw(self)
    end
    public :_render_scene

    # Reset frame to defaults
    def reset_clipping_rect
      @clip_x      = @defaults[:clip_x]
      @clip_y      = @defaults[:clip_y]
      @clip_width  = @defaults[:clip_width]
      @clip_height = @defaults[:clip_height]
    end

    # Set the position of the clipping retangle based on the current frame
    def set_frame
      frames = @animations[@playing_animation]
      case frames
      when Range
        reset_clipping_rect
        @clip_x = @current_frame * @clip_width
      when Array
        set_explicit_frame frames[@current_frame]
      end
    end

    # Reset the playing animation to the first frame
    def reset_playing_animation
      frames = @animations[@playing_animation]
      case frames
      # When animation is a range, play through frames horizontally
      when Range
        @first_frame   = frames.first || @defaults[:frame]
        @current_frame = frames.first || @defaults[:frame]
        @last_frame    = frames.last
        # Range frames carry no per-frame `time:`, so reset to the default
        # rather than inheriting a leftover value from a prior Array animation.
        @frame_time    = @defaults[:frame_time]
      # When array...
      when Array
        @first_frame   = 0
        @current_frame = 0
        @last_frame    = frames.length - 1
      end
    end

    # Set the current frame based on the region/portion of image
    def set_explicit_frame(frame)
      # Defensive: an out-of-range frame index (e.g. a `default:` past the end
      # of the default animation, restored by `stop`) yields nil here. Leave the
      # current frame in place rather than crashing.
      return if frame.nil?

      @clip_x      = frame[:x]      .nil? ? @defaults[:clip_x]      : frame[:x]
      @clip_y      = frame[:y]      .nil? ? @defaults[:clip_y]      : frame[:y]
      @clip_width  = frame[:width]  .nil? ? @defaults[:clip_width]  : frame[:width]
      @clip_height = frame[:height] .nil? ? @defaults[:clip_height] : frame[:height]
      @frame_time  = frame[:time]   .nil? ? @defaults[:frame_time]  : frame[:time]
      @source_width  = frame[:source_width]  || @clip_width
      @source_height = frame[:source_height] || @clip_height
      @trim_x = frame[:trim_x] || 0
      @trim_y = frame[:trim_y] || 0
      @width  = @user_width  || @source_width
      @height = @user_height || @source_height
    end

    # initialize animation, called by constructor
    def setup_animation
      @frame_budget = 0.0
      @playing = false
      @paused = false
      @last_frame = 0
      @done_proc = nil

      # Auto-generate :default only for path-based sprites where the source is
      # a horizontal strip. Atlas sources have arbitrary 2D layouts, so we
      # leave :default to the user.
      @animations[:default] = 0..(@img_width / @clip_width) - 1 unless @sheet

      default_anim = @animations.empty? ? nil : @animations.first[0]

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
    end

    # Resolve frame-name strings against the SpriteSheet so the rest of the
    # class only has to deal with `{x:,y:,width:,height:[,time:]}` rects and
    # numeric Ranges — the same shapes the legacy path-based API uses.
    def normalize_animations(anims)
      result = {}
      anims.each do |name, frames|
        result[name] = case frames
                       when Range  then frames
                       when Array  then frames.map { |f| normalize_frame(f) }
                       when String then [normalize_frame(frames)]
                       else frames
                       end
      end
      result
    end

    def normalize_frame(spec)
      if spec.is_a?(String)
        lookup_sheet_frame(spec).dup
      elsif spec.is_a?(Hash)
        name = spec[:name] || spec['name']
        if name
          rect = lookup_sheet_frame(name).dup
          time = spec[:time] || spec['time']
          rect[:time] = time if time
          rect
        else
          spec
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

    def first_sheet_rect
      first_name = @sheet.frame_names.first
      first_name && lookup_sheet_frame(first_name)
    end
  end
end
