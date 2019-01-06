# Ruby2D::Sprite

module Ruby2D
  class Sprite
    include Renderable

    attr_reader :path
    attr_accessor :rotate, :loop, :clip_x, :clip_y, :clip_width, :clip_height, :data

    def initialize(path, opts = {})
      unless File.exist? path
        raise Error, "Cannot find sprite image file `#{path}`"
      end

      # Sprite image file path
      @path = path

      # Coordinates, size, and rotation of the sprite
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width  = opts[:width]  || nil
      @height = opts[:height] || nil
      @rotate = opts[:rotate] || 0
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]

      # Flipping status, coordinates, and size, used internally
      @flip = nil
      @flip_x = @x
      @flip_y = @y
      @flip_width  = @width
      @flip_height = @height

      # Animation attributes
      @start_time = 0.0
      @loop = opts[:loop] || false
      @frame_time = opts[:time] || 300
      @animations = opts[:animations] || {}
      @playing = false
      @current_frame = opts[:default] || 0
      @last_frame = 0
      @done_proc = nil

      # The sprite image size set by the native extension `ext_init()`
      @img_width = nil; @img_height = nil

      # Initialize the sprite
      unless ext_init(@path)
        raise Error, "Sprite image `#{@path}` cannot be created"
      end

      # The clipping rectangle
      @clip_x = opts[:clip_x] || 0
      @clip_y = opts[:clip_y] || 0
      @clip_width  = opts[:clip_width]  || @img_width
      @clip_height = opts[:clip_height] || @img_height

      # Set the default animation
      @animations[:default] = 0..(@img_width / @clip_width) - 1

      # Set the sprite defaults
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

      # Add the sprite to the window
      add
    end

    # Set the x coordinate
    def x=(x)
      @x = @flip_x = x
      if @flip == :horizontal || @flip == :both
        @flip_x = x + @width
      end
    end

    # Set the y coordinate
    def y=(y)
      @y = @flip_y = y
      if @flip == :vertical || @flip == :both
        @flip_y = y + @height
      end
    end

    # Set the width
    def width=(width)
      @width = @flip_width = width
      if @flip == :horizontal || @flip == :both
        @flip_width = -width
      end
    end

    # Set the height
    def height=(height)
      @height = @flip_height = height
      if @flip == :vertical || @flip == :both
        @flip_height = -height
      end
    end

    # Play an animation
    def play(opts = {}, &done_proc)

      animation = opts[:animation]
      loop = opts[:loop]
      flip = opts[:flip]

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
          @last_frame    = frames.length - 1
        end

        # Set looping
        @loop = loop == true || @defaults[:loop] ? true : false

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

      # The sprite width and height must be set for it to be flipped correctly
      if (!@width || !@height) && flip
        raise Error,
         "Sprite width and height must be set in order to flip; " +
         "occured playing animation `:#{@playing_animation}` with image `#{@path}`"
      end

      @flip = flip

      # Reset flip values
      @flip_x      = @x
      @flip_y      = @y
      @flip_width  = @width
      @flip_height = @height

      case flip
      when :horizontal
        @flip_x      = @x + @width
        @flip_width  = -@width
      when :vertical
        @flip_y      = @y + @height
        @flip_height = -@height
      when :both     # horizontal and vertical
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
