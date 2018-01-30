# sprite.rb

module Ruby2D
  class Sprite
    include Renderable

    attr_accessor :x, :y, :width, :height, :loop,
                  :clip_x, :clip_y, :clip_width, :clip_height, :data

    def initialize(path, opts = {})

      unless RUBY_ENGINE == 'opal'
        unless File.exists? path
          raise Error, "Cannot find sprite image file `#{path}`"
        end
      end

      @path = path
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width  = opts[:width]  || nil
      @height = opts[:height] || nil
      @start_time = 0.0
      @loop = opts[:loop] || false
      @frame_time = opts[:time] || 300
      @animations = opts[:animations] || {}
      @playing = false
      @current_frame = opts[:default] || 0
      @last_frame = 0

      ext_init(@path)
      @clip_x = opts[:clip_x] || 0
      @clip_y = opts[:clip_y] || 0
      @clip_width  = opts[:clip_width]  || @width
      @clip_height = opts[:clip_height] || @height
      @animations[:default] = 0..(@width / @clip_width) - 1  # set default animation

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

    def play(animation = nil, loop = nil)
      if !@playing || (animation != @playing_animation && animation != nil)

        @playing = true
        @playing_animation = animation || :default
        frames = @animations[@playing_animation]

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
    def stop
      @playing = false
      @playing_animation = @defaults[:animation]
      @current_frame = @defaults[:frame]
      set_frame
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
        @frame_time = f[:time]    || @defaults[:frame_time]
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
          unless @loop then stop end
        end

        set_frame
      end
    end

  end
end
