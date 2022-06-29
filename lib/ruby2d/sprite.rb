# frozen_string_literal: true

# Ruby2D::Sprite

module Ruby2D
  # Sprites are special images that can be used to create animations, kind of like a flip book.
  # To create a sprite animation, first you’ll need an image which contains each frame of your animation.
  class Sprite
    include Renderable

    attr_reader :path
    attr_accessor :rotate, :loop, :clip_x, :clip_y, :clip_width, :clip_height, :data, :x, :y, :width, :height

    # Create a sprite via single image or sprite-sheet.
    # @param path [#to_s] The location of the file to load as an image.
    # @param width [Numeric] The +width+ of drawn image, or default is width from image file
    # @param height [Numeric] The +height+ of drawn image, or default is height from image file
    # @param x [Numeric]
    # @param y [Numeric]
    # @param z [Numeric]
    # @param rotate [Numeric] Angle, default is 0
    # @param color [Numeric] (or +colour+) Tint the image when rendering
    # @param opacity [Numeric] Opacity of the image when rendering
    # @param show [Boolean] If +true+ the image is added to +Window+ automatically.
    # @param loop [Boolean] Sets whether animations loop by default when played (can be overridden by +play+ method)
    # @param time [Numeric] The default time in millisecond for each frame (unless overridden animation within frames)
    # @param animations [Hash{String => Range}, Hash{String=>Array<Hash>}] Sprite sheet map to animations using
    #                                                                      frame ranges or individual frames
    # @param default [Numeric] The default initial frame for the sprite
    # @param clip_x [Numeric]
    # @param clip_x [Numeric]
    # @param clip_width [Numeric]
    # @param clip_height [Numeric]
    def initialize(path, atlas: nil, show: true, width: nil, height: nil,
                   x: 0, y: 0, z: 0, rotate: 0, color: nil, colour: nil, opacity: nil,
                   loop: false, time: 300, animations: {}, default: 0,
                   clip_x: 0, clip_y: 0, clip_width: nil, clip_height: nil)
      @path = path.to_s

      # Coordinates, size, and rotation of the sprite
      @x = x
      @y = y
      @z = z
      @rotate = rotate
      self.color = color || colour || 'white'
      self.color.opacity = opacity unless opacity.nil?

      # Dimensions
      @width  = width
      @height = height

      # Flipping status
      @flip = nil

      # Animation attributes
      @loop = loop
      @frame_time = time
      @animations = animations
      @current_frame = default

      _setup_texture_and_clip_box atlas, clip_x, clip_y, clip_width, clip_height
      _setup_animation

      # Add the sprite to the window
      add if show
    end

    # Start playing an animation
    # @param animation [String] Name of the animation to play
    # @param loop [Boolean] Set the animation to loop or not
    # @param flip [nil, :vertical, :horizontal, :both] Direction to flip the sprite if desired
    def play(animation: :default, loop: nil, flip: nil, &done_proc)
      unless @playing && animation == @playing_animation && flip == @flip
        @playing = true
        @playing_animation = animation || :default
        @done_proc = done_proc

        flip_sprite(flip)
        _reset_playing_animation

        loop = @defaults[:loop] if loop.nil?
        @loop = loop ? true : false

        set_frame
        restart_time
      end
      self
    end

    # Stop the current animation and set to the default frame
    def stop(animation = nil)
      return unless !animation || animation == @playing_animation

      @playing = false
      @playing_animation = @defaults[:animation]
      @current_frame = @defaults[:frame]
      set_frame
    end

    # Flip the sprite
    # @param flip [nil, :vertical, :horizontal, :both] Direction to flip the sprite if desired
    def flip_sprite(flip)
      # The sprite width and height must be set for it to be flipped correctly
      if (!@width || !@height) && flip
        raise Error,
              "Sprite width/height required to flip; occured playing animation `:#{@playing_animation}`
               with image `#{@path}`"
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
        _set_explicit_frame frames[@current_frame]
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
      return unless @playing

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

    # @param width [Numeric] The +width+ of drawn image
    # @param height [Numeric] The +height+ of drawn image
    # @param x [Numeric]
    # @param y [Numeric]
    # @param rotate [Numeric] Angle, default is 0
    # @param color [Numeric] (or +colour+) Tint the image when rendering
    # @param clip_x [Numeric]
    # @param clip_x [Numeric]
    # @param clip_width [Numeric]
    # @param clip_height [Numeric]
    def draw(x:, y:, width: (@width || @clip_width), height: (@height || @clip_height), rotate: @rotate,
             clip_x: @clip_x, clip_y: @clip_y, clip_width: @clip_width, clip_height: @clip_height,
             color: [1.0, 1.0, 1.0, 1.0])

      Window.render_ready_check
      render(x: x, y: y, width: width, height: height, color: Color.new(color), rotate: rotate, crop: {
               x: clip_x,
               y: clip_y,
               width: clip_width,
               height: clip_height,
               image_width: @img_width,
               image_height: @img_height
             })
    end

    private

    def render(x: @x, y: @y, width: (@width || @clip_width), height: (@height || @clip_height),
               color: @color, rotate: @rotate, flip: @flip,
               crop: {
                 x: @clip_x,
                 y: @clip_y,
                 width: @clip_width,
                 height: @clip_height,
                 image_width: @img_width,
                 image_height: @img_height
               })
      update
      vertices = Vertices.new(x, y, width, height, rotate, crop: crop, flip: flip)
      @texture.draw vertices.coordinates, vertices.texture_coordinates, color
    end

    # Reset the playing animation to the first frame
    def _reset_playing_animation
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
        @last_frame    = frames.length - 1
      end
    end

    # Set the current frame based on the region/portion of image
    def _set_explicit_frame(frame)
      @clip_x      = frame[:x]      || @defaults[:clip_x]
      @clip_y      = frame[:y]      || @defaults[:clip_y]
      @clip_width  = frame[:width]  || @defaults[:clip_width]
      @clip_height = frame[:height] || @defaults[:clip_height]
      @frame_time  = frame[:time]   || @defaults[:frame_time]
    end

    # initialize texture and clipping, called by constructor
    def _setup_texture_and_clip_box(atlas, clip_x, clip_y, clip_width, clip_height)
      # Initialize the sprite texture
      # Consider input pixmap atlas if supplied to load image file
      @texture = Image.load_image_as_texture @path, atlas: atlas
      @img_width = @texture.width
      @img_height = @texture.height

      # The clipping rectangle
      @clip_x = clip_x
      @clip_y = clip_y
      @clip_width  = clip_width  || @img_width
      @clip_height = clip_height || @img_height
    end

    # initialize animation, called by constructor
    def _setup_animation
      @start_time = 0.0
      @playing = false
      @last_frame = 0
      @done_proc = nil

      # Set the default animation
      @animations[:default] = 0..(@img_width / @clip_width) - 1

      # Set the sprite defaults
      @defaults = {
        animation: @animations.first[0],
        frame: @current_frame,
        frame_time: @frame_time,
        clip_x: @clip_x,
        clip_y: @clip_y,
        clip_width: @clip_width,
        clip_height: @clip_height,
        loop: @loop
      }
    end
  end
end
