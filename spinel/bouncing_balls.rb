# Bouncing balls — Spinel FFI port
#
# A port of `examples/bouncing_balls.rb` to the Spinel build path. The physics
# and tunables are the original's; what differs is the plumbing. Instead of
# `require 'ruby2d'` and the DSL, this talks to the same `R2D_*` C core over
# Spinel's FFI, and owns its main loop in Ruby.
#
# Build (see README.md for libruby2d_core.a):
#   spinel bouncing_balls.rb --cc="cc <frameworks>" --link libruby2d_core.a \
#     --link libSDL3_ttf.a --link libSDL3_image.a --link libSDL3_mixer.a \
#     --link libSDL3.a -o bouncing_balls

module R2D
  # Window lifecycle
  ffi_func :R2D_CreateWindow, [:str, :int, :int, :int, :int, :str], :bool
  ffi_func :R2D_ShowWindow,
           [:str, :int, :int, :bool, :bool, :bool, :double, :int, :int, :str, :str, :str], :bool
  ffi_func :R2D_CloseWindow,  [], :void
  ffi_func :R2D_LastError,    [], :str

  # Per-frame
  ffi_func :R2D_PollEvents,   [], :void
  ffi_func :R2D_PollClosed,   [], :bool
  ffi_func :R2D_PollMouseX,   [], :int
  ffi_func :R2D_PollMouseY,   [], :int
  ffi_func :R2D_BeginFrame,   [:float, :float, :float, :float], :bool
  ffi_func :R2D_EndFrame,     [], :void
  ffi_func :R2D_FrameCount,   [], :int
  ffi_func :R2D_Fps,          [], :double

  # Drawing
  ffi_func :R2D_DrawCircle,
           [:float, :float, :float, :int, :float, :float, :float, :float], :void

  # Screenshot. `R2D_Screenshot` wants the window pointer, which `R2D_GetWindow`
  # hands back — an opaque `:ptr` here, never dereferenced on the Ruby side.
  ffi_func :R2D_GetWindow,  [],            :ptr
  ffi_func :R2D_Screenshot, [:ptr, :str],  :void
end

# === Tunables (from the original example) ===

WIDTH = 800
HEIGHT = 600
INITIAL_BALLS = 20
GRAVITY = 2160.0         # downward acceleration (px/sec²)
WALL_BOUNCE = 0.9        # horizontal velocity retained after wall bounce
FLOOR_BOUNCE = 0.85      # vertical velocity retained after floor bounce
FLOOR_FRICTION = 1.21    # horizontal velocity decay rate on floor contact
CURSOR_PUSH = 90_000.0   # cursor repulsion strength
CURSOR_RADIUS = 140.0    # cursor influence falls off past this

# A plain class rather than the original's `Struct.new`, and it carries its own
# geometry instead of wrapping a `Circle`: with no scene graph here, each ball
# draws itself.
class Ball
  attr_accessor :x, :y, :vx, :vy
  attr_reader :radius, :r, :g, :b

  def initialize(x, y, radius, vx)
    @x = x
    @y = y
    @radius = radius
    @vx = vx
    @vy = 0.0
    @r = rand * 0.6 + 0.4
    @g = rand * 0.6 + 0.4
    @b = rand * 0.6 + 0.4
  end

  def step(dt, mx, my)
    @vy += GRAVITY * dt

    # Cursor repulsion. The original spawns balls on click; button state lives
    # in the event queue, which this path doesn't drain yet, so the cursor
    # pushes instead — enough to show input is live.
    dx = @x - mx
    dy = @y - my
    dist = Math.sqrt(dx * dx + dy * dy)
    if dist < CURSOR_RADIUS && dist > 0.5
      push = CURSOR_PUSH / (dist * dist)
      @vx += dx / dist * push * dt
      @vy += dy / dist * push * dt
    end

    @x += @vx * dt
    @y += @vy * dt

    if @x - @radius < 0
      @x = @radius
      @vx = @vx.abs * WALL_BOUNCE
    elsif @x + @radius > WIDTH
      @x = WIDTH - @radius
      @vx = -@vx.abs * WALL_BOUNCE
    end

    if @y + @radius > HEIGHT
      @y = HEIGHT - @radius
      @vy = -@vy.abs * FLOOR_BOUNCE
      @vx *= Math.exp(-FLOOR_FRICTION * dt)
    elsif @y - @radius < 0
      @y = @radius
      @vy = @vy.abs
    end
  end

  def draw
    R2D.R2D_DrawCircle(@x, @y, @radius, 64, @r, @g, @b, 0.85)
  end
end

def make_ball
  r = 10.0 + rand(26)
  Ball.new(r + rand(WIDTH - r * 2), r + rand(200), r, rand * 720 - 360)
end

# === Window ===

TITLE = 'Ruby 2D on Spinel - Bouncing balls'

unless R2D.R2D_CreateWindow(TITLE, WIDTH, HEIGHT, 0, 0, 'letterbox')
  puts "create failed: #{R2D.R2D_LastError}"
  exit 1
end

unless R2D.R2D_ShowWindow(TITLE, WIDTH, HEIGHT, false, false, false, 60.0,
                          0, 0, 'letterbox', 'continuous', nil)
  puts "show failed: #{R2D.R2D_LastError}"
  exit 1
end

balls = []
INITIAL_BALLS.times { balls << make_ball }

# === Main loop, owned by Ruby ===

# Runs until the window is closed. Pass a frame count to cap it instead, which
# is how the build is smoke-tested without a human closing a window.
max_frames = ARGV[0].nil? ? 0 : ARGV[0].to_i

dt = 1.0 / 60.0
until R2D.R2D_PollClosed || (max_frames > 0 && R2D.R2D_FrameCount >= max_frames)
  R2D.R2D_PollEvents

  mx = R2D.R2D_PollMouseX.to_f
  my = R2D.R2D_PollMouseY.to_f
  balls.each { |ball| ball.step(dt, mx, my) }

  # Background is the original's '#0a0a23'.
  if R2D.R2D_BeginFrame(0.039, 0.039, 0.137, 1.0)
    balls.each(&:draw)
    # Capture the last frame when a path is given, so the build can be checked
    # visually without a human watching the window.
    if !ARGV[1].nil? && max_frames > 0 && R2D.R2D_FrameCount == max_frames - 1
      R2D.R2D_Screenshot(R2D.R2D_GetWindow, ARGV[1])
    end
  end
  R2D.R2D_EndFrame
end

puts "ran #{R2D.R2D_FrameCount} frames at #{R2D.R2D_Fps.round(1)} fps"
R2D.R2D_CloseWindow
