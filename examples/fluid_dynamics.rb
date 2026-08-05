# Fluid dynamics
# A real-time grid fluid sim — a plume rises and the mouse injects currents.
#
# Colored smoke rises automatically from the bottom; move the mouse to
# inject your own currents and add ink. Press space to pause, r to clear.
#
# Algorithm is Jos Stam's "Stable Fluids" (advection, diffusion,
# pressure projection) on a ghost-celled grid; rendered cell-by-cell
# into a Canvas via `fill_pixel_grid` for a single bulk blit per frame.

require 'ruby2d'

# === Tunables ===

WIDTH = 800             # window width in pixels
HEIGHT = 600            # window height in pixels
CELL = 10               # pixel size of one simulation cell
NX = WIDTH / CELL       # grid columns (interior cells)
NY = HEIGHT / CELL      # grid rows (interior cells)
LIN_ITERS = 4           # Gauss-Seidel iterations per linear solve
VISC = 0.00005          # velocity diffusion (viscosity)
DT = 1.0 / 30.0         # numerical sim step size (internal, not wall-clock)
SIM_RATE = 60           # sim steps per second (wall-clock pacing)
DECAY = 0.992           # per-step dye decay (1.0 = lossless)
PLUME_DYE = 8.0         # dye injection rate at the auto-plume center
PLUME_VEL = 1.5         # upward velocity at the auto-plume center
MOUSE_DYE = 20.0        # dye injection rate at the cursor
MOUSE_VEL = 8.0         # velocity per pixel of mouse motion
HUE_RATE = 0.35         # mouse-injection hue cycles per second

SIZE_X = NX + 2         # row stride (interior + 2 ghost cells)
SIZE_Y = NY + 2
SIZE2 = SIZE_X * SIZE_Y

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Fluid dynamics', width: WIDTH, height: HEIGHT, background: '#050816'
set close_on_esc: true

# === Canvas ===

canvas = Canvas.new(width: WIDTH, height: HEIGHT, fill: [0.02, 0.03, 0.08, 1])

# === Solver helpers ===

def set_bnd(b, x)
  # Top/bottom rows (mirror or negate vertical velocity for b == 2)
  1.upto(NX) do |i|
    x[i]                     = b == 2 ? -x[i + SIZE_X]      : x[i + SIZE_X]
    x[i + (NY + 1) * SIZE_X] = b == 2 ? -x[i + NY * SIZE_X] : x[i + NY * SIZE_X]
  end
  # Left/right columns (mirror or negate horizontal velocity for b == 1)
  1.upto(NY) do |j|
    x[j * SIZE_X]          = b == 1 ? -x[1 + j * SIZE_X]  : x[1 + j * SIZE_X]
    x[NX + 1 + j * SIZE_X] = b == 1 ? -x[NX + j * SIZE_X] : x[NX + j * SIZE_X]
  end
  # Four corners — average of the two adjacent edges
  x[0]                          = 0.5 * (x[1] + x[SIZE_X])
  x[(NY + 1) * SIZE_X]          = 0.5 * (x[1 + (NY + 1) * SIZE_X] + x[NY * SIZE_X])
  x[NX + 1]                     = 0.5 * (x[NX] + x[NX + 1 + SIZE_X])
  x[NX + 1 + (NY + 1) * SIZE_X] = 0.5 * (x[NX + (NY + 1) * SIZE_X] + x[NX + 1 + NY * SIZE_X])
end

def lin_solve(b, x, x0, a, c)
  LIN_ITERS.times do
    1.upto(NY) do |j|
      base = j * SIZE_X
      1.upto(NX) do |i|
        idx = i + base
        x[idx] = (x0[idx] + a * (x[idx - 1] + x[idx + 1] + x[idx - SIZE_X] + x[idx + SIZE_X])) / c
      end
    end
    set_bnd(b, x)
  end
end

def diffuse(b, x, x0, diff, dt)
  a = dt * diff * NX * NX
  lin_solve(b, x, x0, a, 1 + 4 * a)
end

def advect(b, d, d0, u, v, dt)
  # Semi-Lagrangian: dt0_x in cells-per-time-unit along x (likewise y), so
  # u and v stay in domain units even when NX != NY.
  dt0_x = dt * NX
  dt0_y = dt * NY
  1.upto(NY) do |j|
    1.upto(NX) do |i|
      idx = i + j * SIZE_X
      x = i - dt0_x * u[idx]
      y = j - dt0_y * v[idx]
      x = 0.5 if x < 0.5
      x = NX + 0.5 if x > NX + 0.5
      y = 0.5 if y < 0.5
      y = NY + 0.5 if y > NY + 0.5
      i0 = x.to_i
      i1 = i0 + 1
      j0 = y.to_i
      j1 = j0 + 1
      s1 = x - i0
      s0 = 1 - s1
      t1 = y - j0
      t0 = 1 - t1
      d[idx] = s0 * (t0 * d0[i0 + j0 * SIZE_X] + t1 * d0[i0 + j1 * SIZE_X]) +
               s1 * (t0 * d0[i1 + j0 * SIZE_X] + t1 * d0[i1 + j1 * SIZE_X])
    end
  end
  set_bnd(b, d)
end

def project(u, v, p, div)
  h = 1.0 / NX
  1.upto(NY) do |j|
    1.upto(NX) do |i|
      idx = i + j * SIZE_X
      div[idx] = -0.5 * h * (u[idx + 1] - u[idx - 1] + v[idx + SIZE_X] - v[idx - SIZE_X])
      p[idx] = 0.0
    end
  end
  set_bnd(0, div)
  set_bnd(0, p)
  lin_solve(0, p, div, 1.0, 4.0)
  1.upto(NY) do |j|
    1.upto(NX) do |i|
      idx = i + j * SIZE_X
      u[idx] -= 0.5 * (p[idx + 1] - p[idx - 1]) / h
      v[idx] -= 0.5 * (p[idx + SIZE_X] - p[idx - SIZE_X]) / h
    end
  end
  set_bnd(1, u)
  set_bnd(2, v)
end

def hsv_to_rgb(h, s, v)
  i = (h * 6).floor
  f = h * 6 - i
  p = v * (1 - s)
  q = v * (1 - f * s)
  tt = v * (1 - (1 - f) * s)
  case i % 6
  when 0 then [v, tt, p]
  when 1 then [q, v, p]
  when 2 then [p, v, tt]
  when 3 then [p, q, v]
  when 4 then [tt, p, v]
  else        [v, p, q]
  end
end

# === Mutable state ===

dye      = Array.new(3) { Array.new(SIZE2, 0.0) }
dye_prev = Array.new(3) { Array.new(SIZE2, 0.0) }
u      = Array.new(SIZE2, 0.0)
u_prev = Array.new(SIZE2, 0.0)
v      = Array.new(SIZE2, 0.0)
v_prev = Array.new(SIZE2, 0.0)

# Render buffer: NX*NY cells × 4 floats (r, g, b, a). Pre-allocated and
# overwritten in place each frame to skip per-frame allocation.
colors = Array.new(NX * NY * 4, 0.0)

mouse_x = WIDTH / 2
mouse_y = HEIGHT / 2
prev_mx = mouse_x
prev_my = mouse_y
mouse_inside = false
paused = false
tick = 0
sim_accum = 0.0

# === Input ===

on :mouse_enter do
  mouse_inside = true
end

on :mouse_leave do
  mouse_inside = false
  # Resync prev on re-entry so the first move post-leave doesn't inject
  # a huge ghost delta from the stale prior position.
  prev_mx = mouse_x
  prev_my = mouse_y
end

on :mouse_move do |event|
  mouse_x = event.x
  mouse_y = event.y
end

on key_down: :space do
  paused = !paused
end

on key_down: :r do
  SIZE2.times do |i|
    u[i] = 0.0
    v[i] = 0.0
    dye[0][i] = 0.0
    dye[1][i] = 0.0
    dye[2][i] = 0.0
  end
  canvas.clear
end

# === Per-frame update ===

update do |dt|
  next if paused
  dt = [dt, 1.0 / 30].min  # cap so a stall can't trigger a runaway catch-up

  sim_accum += SIM_RATE * dt
  count = sim_accum.to_i
  sim_accum -= count

  count.times do
    tick += 1

    # Reset source buffers; injectors below write into them.
    SIZE2.times do |i|
      u_prev[i] = 0.0
      v_prev[i] = 0.0
      dye_prev[0][i] = 0.0
      dye_prev[1][i] = 0.0
      dye_prev[2][i] = 0.0
    end

    # Auto-plume at the bottom — disk of warm dye + upward velocity, with
    # a sin-wave horizontal sway to keep the plume from being too tidy.
    plume_cx = NX / 2 + (Math.sin(tick * 0.04) * NX * 0.18).round
    plume_cy = NY - 3
    plume_rgb = hsv_to_rgb((elapsed * HUE_RATE * 0.3) % 1.0, 0.8, 1.0)
    -3.upto(3) do |oy|
      -3.upto(3) do |ox|
        next if ox * ox + oy * oy > 10
        x = plume_cx + ox
        y = plume_cy + oy
        next unless x.between?(1, NX) && y.between?(1, NY)
        falloff = 1.0 - Math.sqrt(ox * ox + oy * oy) / 4.0
        idx = x + y * SIZE_X
        dye_prev[0][idx] = plume_rgb[0] * falloff * PLUME_DYE
        dye_prev[1][idx] = plume_rgb[1] * falloff * PLUME_DYE
        dye_prev[2][idx] = plume_rgb[2] * falloff * PLUME_DYE
        u_prev[idx] = Math.sin(tick * 0.07) * falloff * PLUME_VEL * 0.4
        v_prev[idx] = -falloff * PLUME_VEL
      end
    end

    if mouse_inside
      cx = (mouse_x.to_f / CELL).to_i.clamp(1, NX)
      cy = (mouse_y.to_f / CELL).to_i.clamp(1, NY)
      # Mouse delta stays in pixels so MOUSE_VEL is comparable to stable_fluids'
      # VEL_INJECT — a 1px drag injects MOUSE_VEL units of velocity.
      mdx = (mouse_x - prev_mx).to_f
      mdy = (mouse_y - prev_my).to_f
      mouse_rgb = hsv_to_rgb((elapsed * HUE_RATE) % 1.0, 0.85, 1.0)
      -2.upto(2) do |oy|
        -2.upto(2) do |ox|
          next if ox * ox + oy * oy > 6
          x = (cx + ox).clamp(1, NX)
          y = (cy + oy).clamp(1, NY)
          falloff = 1.0 - Math.sqrt(ox * ox + oy * oy) / 3.0
          idx = x + y * SIZE_X
          dye_prev[0][idx] += mouse_rgb[0] * falloff * MOUSE_DYE
          dye_prev[1][idx] += mouse_rgb[1] * falloff * MOUSE_DYE
          dye_prev[2][idx] += mouse_rgb[2] * falloff * MOUSE_DYE
          u_prev[idx] += mdx * falloff * MOUSE_VEL
          v_prev[idx] += mdy * falloff * MOUSE_VEL
        end
      end
    end
    prev_mx = mouse_x
    prev_my = mouse_y

    # Velocity step: add sources, diffuse, project, advect, project
    SIZE2.times do |i|
      u[i] += DT * u_prev[i]
      v[i] += DT * v_prev[i]
    end
    u, u_prev = u_prev, u
    diffuse(1, u, u_prev, VISC, DT)
    v, v_prev = v_prev, v
    diffuse(2, v, v_prev, VISC, DT)
    project(u, v, u_prev, v_prev)
    u, u_prev = u_prev, u
    v, v_prev = v_prev, v
    advect(1, u, u_prev, u_prev, v_prev, DT)
    advect(2, v, v_prev, u_prev, v_prev, DT)
    project(u, v, u_prev, v_prev)

    # Dye step per channel: add sources, advect by the divergence-free
    # velocity field, then decay.
    3.times do |c|
      d = dye[c]
      d_prev = dye_prev[c]
      SIZE2.times { |i| d[i] += DT * d_prev[i] }
      dye[c], dye_prev[c] = dye_prev[c], dye[c]
      advect(0, dye[c], dye_prev[c], u, v, DT)
      d = dye[c]
      SIZE2.times { |i| d[i] *= DECAY }
    end
  end

  # === Render ===
  #
  # Pack the interior cells into the pre-allocated colors buffer and blit
  # in one `fill_pixel_grid` call. Per-cell clamps keep colors in 0..1;
  # alpha is the channel sum (capped) so empty cells stay transparent.
  dr = dye[0]
  dg = dye[1]
  db = dye[2]
  ci = 0
  1.upto(NY) do |j|
    base = j * SIZE_X
    1.upto(NX) do |i|
      idx = i + base
      r = dr[idx]
      g = dg[idx]
      b = db[idx]
      r = 0.0 if r < 0.0
      r = 1.0 if r > 1.0
      g = 0.0 if g < 0.0
      g = 1.0 if g > 1.0
      b = 0.0 if b < 0.0
      b = 1.0 if b > 1.0
      a = r + g + b
      a = 1.0 if a > 1.0
      colors[ci]     = r
      colors[ci + 1] = g
      colors[ci + 2] = b
      colors[ci + 3] = a
      ci += 4
    end
  end

  canvas.clear
  canvas.fill_pixel_grid(cols: NX, rows: NY, cell_w: CELL, cell_h: CELL, colors: colors)
end

show
