# sprite.rb

module Ruby2D
  class Sprite
    
    attr_accessor :x, :y, :clip_x, :clip_y, :clip_w, :clip_h, :data
    attr_reader :z
    
    def initialize(x, y, path, z=0)
      
      # unless File.exists? path
      #   raise Error, "Cannot find image file `#{path}`"
      # end
      
      @type_id = 4
      @x, @y, @z, @path = x, y, z, path
      @clip_x, @clip_y, @clip_w, @clip_h = 0, 0, 0, 0
      @default = nil
      @animations = {}
      @current_animation = nil
      @current_frame = 0
      @current_frame_time = 0
      
      init(path)
      if Module.const_defined? :DSL
        Application.add(self)
      end
    end
    
    def start(x, y, w, h)
      @default = [x, y, w, h]
      clip(x, y, w, h)
    end
    
    def add(animations)
      @animations.merge!(animations)
    end
    
    def animate(animation)
      if @current_animation != animation
        @current_frame      = 0
        @current_frame_time = 0
        @current_animation  = animation
      end
      animate_frames(@animations[animation])
    end
    
    def reset
      clip(@default[0], @default[1], @default[2], @default[3])
      @current_animation = nil
    end
    
    # TODO: Sprite already has an `add` method, have to reconsile
    # def add
    #   if Module.const_defined? :DSL
    #     Application.add(self)
    #   end
    # end
    
    def remove
      if Module.const_defined? :DSL
        Application.remove(self)
      end
    end

    def z=(z)
      @z = z
      Application.z_sort
    end    
    
    private
    
    def clip(x, y, w, h)
      @clip_x, @clip_y, @clip_w, @clip_h = x, y, w, h
    end
    
    def animate_frames(frames)
      if @current_frame_time < frames[@current_frame][4]
        clip_with_current_frame(frames)
        @current_frame_time += 1
      else
        @current_frame += 1
        if @current_frame == frames.length
          @current_frame = 0
        end
        clip_with_current_frame(frames)
        @current_frame_time = 0
      end
    end
    
    def clip_with_current_frame(frames)
      clip(frames[@current_frame][0], frames[@current_frame][1],
           frames[@current_frame][2], frames[@current_frame][3])
    end
    
  end
end
