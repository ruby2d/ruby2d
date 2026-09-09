# `Window#delta_time` is the engine's one shared frame delta: zero on the
# first frame, the monotonic gap between updates after that, and clamped to
# 0.1s so a paused window or stalled frame doesn't teleport the simulation.
RSpec.describe 'Window#delta_time' do
  let(:window) { Ruby2D::Window.new }

  def tick_at(seconds)
    allow(Ruby2D::Ext).to receive(:now).and_return(seconds)
    window.update_callback
  end

  it 'is 0.0 on the first frame' do
    tick_at(5.0)
    expect(window.delta_time).to eq(0.0)
  end

  it 'is the elapsed time between updates' do
    tick_at(5.0)
    tick_at(5.016)
    expect(window.delta_time).to be_within(1e-9).of(0.016)
  end

  it 'clamps a stalled frame to 0.1 seconds' do
    tick_at(5.0)
    tick_at(9.0)
    expect(window.delta_time).to eq(0.1)
  end

  it 'passes the delta to an update block that takes an argument' do
    received = nil
    window.update { |dt| received = dt }
    tick_at(5.0)
    tick_at(5.032)
    expect(received).to be_within(1e-9).of(0.032)
  end

  # A proc whose only parameter is optional has arity 0, like one with none,
  # but still takes the delta; only a lambda declared without parameters
  # would reject it.
  it 'passes the delta to a block whose parameter has a default' do
    received = nil
    window.update { |dt = :missing| received = dt }
    tick_at(5.0)
    tick_at(5.032)
    expect(received).to be_within(1e-9).of(0.032)
  end

  it 'passes the delta to a lambda with an optional parameter' do
    received = nil
    window.update(&->(dt = :missing) { received = dt })
    tick_at(5.0)
    tick_at(5.032)
    expect(received).to be_within(1e-9).of(0.032)
  end

  it 'calls a lambda that takes no parameters without one' do
    calls = 0
    window.update(&-> { calls += 1 })
    expect { tick_at(5.0) }.not_to raise_error
    expect(calls).to eq(1)
  end

  # On CRuby a Method's proc is a lambda with the method's arity; mruby wraps
  # it in a splat lambda, so there a zero-parameter method still gets `dt`
  it 'calls a method that takes no parameters without one' do
    counter = Class.new { attr_reader :calls; def tick; @calls = (@calls || 0) + 1; end }.new
    window.update(&counter.method(:tick))
    expect { tick_at(5.0) }.not_to raise_error
    expect(counter.calls).to eq(1)
  end

  # `Window#_clock` is the window's clock: the sum of every tick's clamped
  # delta since the window was created. It runs on ticks, drawn or not, so a
  # `Sprite` drawn by the scene can advance by however much it moved since the
  # sprite's previous draw, and a tick that skips drawing in `:on_demand` mode
  # delays the picture, not the animation.
  describe '#_clock' do
    def tick(seconds, render:)
      allow(Ruby2D::Ext).to receive(:poll_events)
      allow(Ruby2D::Ext).to receive(:drain_events).and_return(nil)
      allow(Ruby2D::Ext).to receive(:begin_frame).and_return(render)
      allow(Ruby2D::Ext).to receive(:end_frame)
      allow(Ruby2D::Ext).to receive(:now).and_return(seconds)
      window.tick
    end

    it 'is 0.0 before any tick' do
      expect(window._clock).to eq(0.0)
    end

    it 'adds up the deltas of every tick, drawn or not' do
      tick(5.0, render: true)
      tick(5.025, render: false)
      tick(5.050, render: true)
      tick(5.075, render: false)
      expect(window._clock).to be_within(1e-9).of(0.075)
    end

    it 'counts a stall once, as the clamped delta does' do
      tick(5.0, render: true)
      tick(9.0, render: false)
      tick(9.016, render: false)
      expect(window._clock).to be_within(1e-9).of(0.116)
    end
  end
end
