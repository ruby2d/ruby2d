# The native `Ruby2D::Ext.*` surface trusts its caller for array lengths. The
# public shape classes always pass matching arrays, but a direct/mismatched call
# must raise a clear error rather than reading past the end (NUM2DBL(nil), which
# hard-aborts on mruby). These guards fire before any rendering, so no window is
# needed.
RSpec.describe 'Ruby2D::Ext array-length guards' do
  it 'raises when draw_polygon is given too few colors' do
    # 3 vertices need 12 color values (4 per vertex); only 4 are given.
    expect {
      Ruby2D::Ext.draw_polygon([0, 0, 10, 0, 10, 10], [1.0, 1.0, 1.0, 1.0])
    }.to raise_error(/draw_polygon/)
  end

  it 'raises when stroke_path is given too few colors' do
    expect {
      Ruby2D::Ext.stroke_path([0, 0, 10, 0, 10, 10], 2.0, [1.0, 1.0, 1.0, 1.0], true)
    }.to raise_error(/stroke_path/)
  end
end
