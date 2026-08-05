# 3D wireframe
# A wireframe sphere drawn entirely from 2D `Polyline` primitives.
#
# Each frame, the sphere's vertices are rotated in 3D, perspective-
# projected onto the screen, and every latitude / longitude line is
# laid down as a depth-shaded polyline so the back of the sphere reads
# as further away. Click and drag to spin it; let go and it keeps
# rotating.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
N_LAT = 9                # number of latitude rings between the poles
N_LON = 18               # longitudes / segments per ring
RADIUS = 220             # sphere radius in pixels
CAMERA = 4.0             # camera distance in unit-sphere coordinates
AUTO_ROT_X = 0.30        # idle rotation rate around X (rad/sec)
AUTO_ROT_Y = 0.55        # idle rotation rate around Y (rad/sec)
DRAG_SENS = 0.006        # screen-pixels → radians for mouse drag

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ 3D wireframe',
    width: WIDTH, height: HEIGHT, background: '#06081a'
set close_on_esc: true

# === Geometry: sphere ===

# Lat row i sits at theta = π·(i+1)/(N_LAT+1) so it lies between, but
# never on, the poles. The poles are stored as their own vertices and
# referenced by every longitude line.
SPHERE = []
N_LAT.times do |i|
  theta = Math::PI * (i + 1) / (N_LAT + 1)
  N_LON.times do |j|
    phi = 2 * Math::PI * j / N_LON
    SPHERE << [Math.sin(theta) * Math.cos(phi),
               Math.cos(theta),
               Math.sin(theta) * Math.sin(phi)]
  end
end
NORTH = SPHERE.length;     SPHERE << [0,  1, 0]
SOUTH = SPHERE.length;     SPHERE << [0, -1, 0]
SPHERE.freeze

# === State ===

rot_x = 0.4
rot_y = 0.0
drag_from = nil

# === Input ===

on :mouse_down do |event|
  drag_from = [event.x, event.y]
end

on :mouse_up do
  drag_from = nil
end

on :mouse_move do |event|
  next unless drag_from

  rot_y += (event.x - drag_from[0]) * DRAG_SENS
  rot_x += (event.y - drag_from[1]) * DRAG_SENS
  drag_from[0] = event.x
  drag_from[1] = event.y
end

# === Per-frame update ===

update do |dt|
  unless drag_from
    rot_x += AUTO_ROT_X * dt
    rot_y += AUTO_ROT_Y * dt
  end
end

# === Render ===

CX = WIDTH  / 2
CY = HEIGHT / 2

# Per-vertex color is derived from projected depth so the polylines
# brighten as they wrap toward the camera and dim into navy on the far
# side. `Polyline` interpolates the colors along the path.
def shade(z)
  t = ((z + 1.0) * 0.5).clamp(0.0, 1.0)  # z in [-1, 1] → t in [0, 1]
  [0.30 + 0.65 * t, 0.55 + 0.40 * t, 0.85 + 0.15 * t, 0.30 + 0.70 * t]
end

render do
  cx_a = Math.cos(rot_x); sx_a = Math.sin(rot_x)
  cy_a = Math.cos(rot_y); sy_a = Math.sin(rot_y)

  # Project every sphere vertex once.
  proj = SPHERE.map do |v|
    x, y, z = v
    y2 =  y * cx_a - z * sx_a
    z2 =  y * sx_a + z * cx_a
    x3 =  x * cy_a + z2 * sy_a
    z3 = -x * sy_a + z2 * cy_a
    f  = CAMERA / (CAMERA - z3)
    [CX + x3 * RADIUS * f, CY + y2 * RADIUS * f, z3]
  end

  # Latitude rings — closed polylines around each row.
  N_LAT.times do |i|
    pts = []
    colors = []
    N_LON.times do |j|
      p = proj[i * N_LON + j]
      pts << [p[0], p[1]]
      colors << shade(p[2])
    end
    Polyline.render(points: pts, color: colors, stroke_width: 1.5, closed: true)
  end

  # Longitude arcs — each runs from the north pole down through one
  # column of lat vertices to the south pole.
  N_LON.times do |j|
    pts = [[proj[NORTH][0], proj[NORTH][1]]]
    colors = [shade(proj[NORTH][2])]
    N_LAT.times do |i|
      p = proj[i * N_LON + j]
      pts << [p[0], p[1]]
      colors << shade(p[2])
    end
    pts << [proj[SOUTH][0], proj[SOUTH][1]]
    colors << shade(proj[SOUTH][2])
    Polyline.render(points: pts, color: colors, stroke_width: 1.5)
  end
end

show
