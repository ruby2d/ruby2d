# Benchmark — Baseline
#
# Empty window with no objects and no per-frame Ruby work. Anchors the
# frame-loop and event-pump overhead so other benchmarks can be read
# relative to the empty-window ceiling.
#
# Why it matters: every other benchmark's measured cost layers on top of
# this idle frame loop. Without a baseline, a regression in (e.g.) sprite
# throughput could be a sprite issue, a frame-loop issue, or OS-level
# scheduling. Run this first when investigating a regression.

require 'ruby2d'
require 'ruby2d/benchmark'

Ruby2D::Benchmark.run('Baseline') do
  set title: 'Ruby 2D Benchmark — Baseline', width: 1280, height: 720
end
