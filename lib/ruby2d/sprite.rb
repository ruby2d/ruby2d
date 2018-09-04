# sprite.rb

module Ruby2D
  class Sprite
    include Renderable

    attr_reader   :x, :y, :width, :height
    attr_accessor :rotate, :loop, :clip_x, :clip_y, :clip_width, :clip_height, :data

    def initialize(path, opts = {})

      unless RUBY_ENGINE == 'opal'
        unless File.exists? path
          raise Error, "Cannot find sprite image file `#{path}`"
        end
      end

      @path          = path
      @x             = opts[:x] || 0
      @y             = opts[:y] || 0
      @z             = opts[:z] || 0
      @flip_x        = @x
      @flip_y        = @y
      @width         = opts[:width]  || nil
      @height        = opts[:height] || nil
      @flip_width    = @width
      @flip_height   = @height
      @clip_x        = opts[:clip_x] || 0
      @clip_y        = opts[:clip_y] || 0
      @rotate        = 0
      @start_time    = 0.0
      @loop          = opts[:loop] || false
      @frame_time    = opts[:time] || 300
      @animations    = opts[:animations] || {}
      @playing       = false
      @current_frame = opts[:default] || 0
      @last_frame    = 0
      @flip          = nil
      @done_proc     = nil

      @img_width = nil; @img_height = nil  # set by `ext_init`
      ext_init(@path)
      @clip_width           = opts[:clip_width]  || @img_width
      @clip_height          = opts[:clip_height] || @img_height
      @animations[:default] = 0..(@img_width / @clip_width) - 1  # set default animation

      @defaults = {
        animation:   @animations.first[0],
        frame:       @current_frame,
        frame_time:  @frame_time,
        clip_x:      @clip_x,
        clip_y:      @clip_y,
        clip_width:  @clip_width,
        clip_height: @clip_height,
        loop:        @loop
      }

      add
    end

    # Set the x coordinate
    def x=(x)
      @x = @flip_x = x
      if @flip == :flip_h || @flip == :flip_hv
        @flip_x = x + @width
      end
    end

    # Set the y coordinate
    def y=(y)
      @y = @flip_y = y
      if @flip == :flip_v || @flip == :flip_hv
        @flip_y = y + @height
      end
    end

    # Set the width
    def width=(width)
      @width = @flip_width = width
      if @flip == :flip_h || @flip == :flip_hv
        @flip_width = -width
      end
    end

    # Set the height
    def height=(height)
      @height = @flip_height = height
      if @flip == :flip_v || @flip == :flip_hv
        @flip_height = -height
      end
    end

    # Play an animation
    def play(animation = nil, loop = nil, flip = nil, &done_proc)
      if !@playing || (animation != @playing_animation && animation != nil) || flip != @flip

        @playing = true
        @playing_animation = animation || :default
        frames = @animations[@playing_animation]
        flip_sprite(flip)
        @done_proc = done_proc

        case frames
        # When animation is a range, play through frames horizontally
        when Range
          @first_frame   = frames.first || @defaults[:frame]
          @current_frame = frames.first || @defaults[:frame]
          @last_frame    = frames.last
        # When array...
        when Array
          @first_frame   = 0
          @current_frame = 0
          @last_frame = frames.length - 1
        end

        # Set looping
        @loop = loop == :loop || @defaults[:loop] ? true : false

        set_frame
        restart_time
      end
    end

    # Stop the current animation and set to the default frame
    def stop(animation = nil)
      if !animation || animation == @playing_animation
        @playing = false
        @playing_animation = @defaults[:animation]
        @current_frame = @defaults[:frame]
        set_frame
      end
    end

    # Flip the sprite
    def flip_sprite(flip)

      # A width and height must be set for the sprite for this to work
      unless @width && @height then return end

      @flip = flip

      # Reset flip values
      @flip_x      = @x
      @flip_y      = @y
      @flip_width  = @width
      @flip_height = @height

      case flip
      when :flip_h   # horizontal
        @flip_x      = @x + @width
        @flip_width  = -@width
      when :flip_v   # vertical
        @flip_y      = @y + @height
        @flip_height = -@height
      when :flip_hv  # horizontal and vertical
        @flip_x      = @x + @width
        @flip_width  = -@width
        @flip_y      = @y + @height
        @flip_height = -@height
      end
    end

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
        f = frames[@current_frame]
        @clip_x      = f[:x]      || @defaults[:clip_x]
        @clip_y      = f[:y]      || @defaults[:clip_y]
        @clip_width  = f[:width]  || @defaults[:clip_width]
        @clip_height = f[:height] || @defaults[:clip_height]
        @frame_time  = f[:time]   || @defaults[:frame_time]
      end
    end

    # Calculate the time in ms
    def elapsed_time
      (Time.now.to_f - @start_time) * 1000
    end

    # Restart the timer
    def restart_time
      @start_time = Time.now.to_f
    end

    # Update the sprite animation, called by `Sprite#ext_render`
    def update
      if @playing

        # Advance the frame
        unless elapsed_time <= (@frame_time || @defaults[:frame_time])
          @current_frame += 1
          restart_time
        end

        # Reset to the starting frame if all frames played
        if @current_frame > @last_frame
          @current_frame = @first_frame
          unless @loop
            # Stop animation and play block, if provided
            stop
            if @done_proc then @done_proc.call end
            @done_proc = nil
          end
        end

        set_frame
      end
    end

  end
end
