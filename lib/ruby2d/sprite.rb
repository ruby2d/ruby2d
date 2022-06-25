# Ruby2D::Sprite

module Ruby2D
  class Sprite
    include Renderable

    attr_reader :path
    attr_accessor :rotate, :loop, :clip_x, :clip_y, :clip_width, :clip_height, :data, :x, :y, :width, :height

    def initialize(path, opts = {})
      # Sprite image file path
      @path = path.to_s

      # Initialize the sprite texture
      # Consider input pixmap atlas if supplied to load image file
      @texture = Image.load_image_as_texture @path, atlas: opts[:atlas]
      @img_width = @texture.width
      @img_height = @texture.height

      # Coordinates, size, and rotation of the sprite
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @rotate = opts[:rotate] || 0
      self.color = opts[:color] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]

      # Flipping status
      @flip = nil

      # Animation attributes
      @start_time = 0.0
      @loop = opts[:loop] || false
      @frame_time = opts[:time] || 300
      @animations = opts[:animations] || {}
      @playing = false
      @current_frame = opts[:default] || 0
      @last_frame = 0
      @done_proc = nil

      # The clipping rectangle
      @clip_x = opts[:clip_x] || 0
      @clip_y = opts[:clip_y] || 0
      @clip_width  = opts[:clip_width]  || @img_width
      @clip_height = opts[:clip_height] || @img_height

      # Dimensions
      @width  = opts[:width]  || nil
      @height = opts[:height] || nil

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
      unless opts[:show] == false then add end
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

        @loop =
          if loop != nil
            loop
          else
            @defaults[:loop] ? true : false
          end

        set_frame
        restart_time
      end
      self
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

    # Update the sprite animation, called by `render`
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
            if @done_proc
              # allow proc to make nested `play/do` calls to sequence multiple
              # animations by clearing `@done_proc` before the call
              kept_done_proc = @done_proc
              @done_proc = nil
              kept_done_proc.call
            end
          end
        end

        set_frame
      end
    end

    def draw(opts = {})
      Window.render_ready_check

      opts[:width] = opts[:width] || (@width || @clip_width)
      opts[:height] = opts[:height] || (@height || @clip_height)
      opts[:rotate] = opts[:rotate] || @rotate
      opts[:clip_x] = opts[:clip_x] || @clip_x
      opts[:clip_y] = opts[:clip_y] || @clip_y
      opts[:clip_width] = opts[:clip_width] || @clip_width
      opts[:clip_height] = opts[:clip_height] || @clip_height
      unless opts[:color]
        opts[:color] = [1.0, 1.0, 1.0, 1.0]
      end

      render(x: opts[:x], y: opts[:y], width: opts[:width], height: opts[:height], color: Color.new(color), rotate: opts[:rotate], crop: {
        x: opts[:clip_x],
        y: opts[:clip_y],
        width: opts[:clip_width],
        height: opts[:clip_height],
        image_width: @img_width,
        image_height: @img_height,
      })
    end

    private

    def render(x: @x, y: @y, width: (@width || @clip_width), height: (@height || @clip_height) , color: @color, rotate: @rotate, flip: @flip, crop: {
      x: @clip_x,
      y: @clip_y,
      width: @clip_width,
      height: @clip_height,
      image_width: @img_width,
      image_height: @img_height,
    })
      update

      vertices = Vertices.new(x, y, width, height, rotate, crop: crop, flip: flip)

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end
  end
end
