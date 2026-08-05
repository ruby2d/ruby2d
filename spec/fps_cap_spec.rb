# `fps_cap` accepts nil (no cap), a positive number, or "uncapped" spelled either
# `Float::INFINITY` or `:infinity` (normalized to the former). The constructor is
# strict (raises); the runtime setter is lenient (warns and falls back to nil).
# The suite's global before(:each) resets `DSL.window`, but these examples build
# several windows each, so they reset it themselves between constructions.
RSpec.describe 'Window fps_cap' do
  describe 'construction (strict)' do
    it 'accepts nil, a positive number, Float::INFINITY, and :infinity' do
      [nil, 60, 144.5, Float::INFINITY, :infinity].each do |cap|
        Ruby2D::DSL.window = nil
        expect { Ruby2D::Window.new(fps_cap: cap) }.not_to raise_error
      end
    end

    it 'raises on 0, negative, NaN, or an unknown value' do
      [0, -5, Float::NAN, :nope, 'fast'].each do |cap|
        Ruby2D::DSL.window = nil
        expect { Ruby2D::Window.new(fps_cap: cap) }.to raise_error(Ruby2D::Error, /fps_cap/)
      end
    end

    it 'normalizes :infinity to Float::INFINITY' do
      Ruby2D::DSL.window = nil
      expect(Ruby2D::Window.new(fps_cap: :infinity).fps_cap).to eq(Float::INFINITY)
    end
  end

  describe '#set (runtime, lenient)' do
    it 'stores nil, a positive number, or infinity (:infinity normalized)' do
      Ruby2D::DSL.window = nil
      w = Ruby2D::Window.new
      w.set(fps_cap: 120);       expect(w.fps_cap).to eq(120)
      w.set(fps_cap: :infinity); expect(w.fps_cap).to eq(Float::INFINITY)
      w.set(fps_cap: nil);       expect(w.fps_cap).to be_nil
    end

    it 'warns and falls back to nil on an invalid value' do
      Ruby2D::DSL.window = nil
      w = Ruby2D::Window.new
      w.set(fps_cap: 120)
      expect { w.set(fps_cap: 0) }.to output(/fps_cap/).to_stderr
      expect(w.fps_cap).to be_nil
    end
  end
end
