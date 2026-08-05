module Ruby2D
  # Lightweight benchmarking harness for Ruby 2D rendering performance.
  #
  # Runs a scene with fps_cap: :infinity (vsync off, no frame cap) and records
  # per-frame deltas plus GC activity over a timed window.
  # After a warmup period the harness samples each frame's duration,
  # then auto-closes and prints a frame-time histogram and GC summary.
  #
  # Usage:
  #
  #   Ruby2D::Benchmark.run('My Scene', warmup: 10, duration: 5) do
  #     # set up your scene / render block here
  #   end
  #
  class Benchmark
    DEFAULTS = { warmup: 10, duration: 5 }.freeze

    # Per-frame CPU/present split. The wall-clock frame delta the harness
    # records includes `SDL_RenderPresent`, which on a desktop compositor can
    # be the dominant, floor-setting cost — so raw fps hides whether a change
    # moved the CPU work at all (an empty window can even measure slower than a
    # populated one). These accumulators, filled by the two wrappers installed
    # in `run`, let the report separate CPU-build time from the present wait.
    #   present_ns — time inside `Ext.end_frame` (≈ present; the cap delay is
    #                off at fps_cap :infinity)
    #   render_ns  — time inside `Window#render_objects` (scene-graph draw:
    #                dispatch + FFI marshaling, plus any `render do` block)
    # Both are summed per frame and read+reset each update tick. Wrapper-only
    # state lives here (module methods can't close over harness locals); it is
    # bench-only and never loaded by the gem proper.
    module Clock
      class << self
        attr_accessor :present_ns, :render_ns
      end
      self.present_ns = 0.0
      self.render_ns  = 0.0
    end

    # Wraps `Ext.end_frame` to accumulate present time. Prepended to the Ext
    # singleton in `run`. The extra `Ext.now` reads are sub-microsecond and
    # apply to every benchmark equally, so A/B comparisons stay consistent.
    module PresentTimer
      def end_frame(*args)
        t = Ext.now
        super
      ensure
        Clock.present_ns += Ext.now - t
      end
    end

    # Wraps `Window#render_objects` to accumulate scene-graph draw time.
    # Prepended to the benchmark window's singleton in `run`.
    module RenderTimer
      def render_objects(*args)
        t = Ruby2D::Ext.now
        super
      ensure
        Clock.render_ns += Ruby2D::Ext.now - t
      end
    end

    attr_reader :name, :warmup, :duration

    def initialize(name, warmup: DEFAULTS[:warmup], duration: DEFAULTS[:duration])
      @name     = name
      @warmup   = warmup
      @duration = duration
    end

    def self.run(name, **opts, &block)
      new(name, **opts).run(&block)
    end

    def run(&setup)
      frame_times   = []
      cpu_times     = []
      render_times  = []
      phase         = :warmup
      phase_start   = nil
      warmup_frames = 0
      measure_start = nil
      prev_t        = nil

      gc_alloc_start = nil
      gc_minor_start = nil
      gc_major_start = nil
      # mruby (the web build) has no `GC.stat`; skip the allocation section
      # there rather than fault. CRuby reports it as before.
      gc_available = GC.respond_to?(:stat)
      @reported = false

      w = DSL.window

      # Install the CPU/present split probes (idempotent — prepend is a no-op
      # if the module is already in the ancestor chain from a prior run).
      Ext.singleton_class.prepend(PresentTimer)
      w.singleton_class.prepend(RenderTimer)

      # Uncap frame rate so we measure raw throughput
      w.set(fps_cap: :infinity)

      # Let the caller configure the scene (add objects, render blocks, etc.)
      setup.call

      # Chain any update proc the setup block registered so per-frame
      # benchmark work runs alongside the harness phase logic.
      user_update = w.instance_variable_get(:@update_proc)

      w.update do
        # Monotonic clock (matching the engine): immune to wall-clock jumps that
        # would corrupt the frame-time histogram mid-measurement.
        now = Ext.now

        # Lazily initialise the phase timer on the first real frame —
        # this avoids counting window-creation overhead as warmup time.
        first_frame = phase_start.nil?
        if first_frame
          phase_start = now
          prev_t = now
        end

        delta = now - prev_t
        prev_t = now

        # Read + reset the split the wrappers accumulated since the previous
        # update tick — i.e. the frame that just completed, the same frame
        # `delta` spans. `cpu` is the frame minus its present wait; clamp away
        # sub-microsecond clock jitter that could make it momentarily negative.
        present = Clock.present_ns
        render  = Clock.render_ns
        Clock.present_ns = 0.0
        Clock.render_ns  = 0.0
        cpu = delta - present
        cpu = 0.0 if cpu.negative?

        # Run the caller's update proc, forwarding the frame delta if it takes
        # one (mirrors Window#update_callback's arity handling).
        if user_update
          user_update.arity.zero? ? user_update.call : user_update.call(delta)
        end

        next if first_frame  # exclude the first frame from phase timing

        case phase
        when :warmup
          warmup_frames += 1
          if now - phase_start >= @warmup
            phase = :measure
            measure_start = now
            if gc_available
              gc_alloc_start = GC.stat(:total_allocated_objects)
              gc_minor_start = GC.stat(:minor_gc_count)
              gc_major_start = GC.stat(:major_gc_count)
            end
          end
        when :measure
          frame_times  << delta
          cpu_times    << cpu
          render_times << render
          if now - measure_start >= @duration
            if gc_available
              @gc_alloc_delta = GC.stat(:total_allocated_objects) - gc_alloc_start
              @gc_minor_delta = GC.stat(:minor_gc_count) - gc_minor_start
              @gc_major_delta = GC.stat(:major_gc_count) - gc_major_start
            end
            # Print from inside the loop: on the web build `w.show` never
            # returns (emscripten unwinds the C stack, and `close` is a no-op
            # there), so a report after `show` would be dead code
            # there. The `@reported` guard keeps it to a single print.
            unless @reported
              report(frame_times, cpu_times, render_times, warmup_frames)
              @reported = true
            end
            w.close
          end
        end
      end

      w.show

      # CRuby returns here once the window closes; the web build never does
      # (it reported from inside the loop above). Report only if the loop
      # somehow exited without doing so.
      report(frame_times, cpu_times, render_times, warmup_frames) unless @reported
    end

    private

    def report(frame_times, cpu_times, render_times, warmup_frames)
      puts "Ruby 2D Benchmark — #{@name}"
      puts '-' * 60

      if frame_times.empty?
        puts '  No samples collected!'
        puts
        return
      end

      total       = frame_times.size
      total_time  = frame_times.sum
      avg_ms      = (total_time * 1000.0) / total
      fps         = total / total_time

      sorted   = frame_times.sort
      pct      = ->(s, p) { s[[(s.size * p).floor, s.size - 1].min] * 1000.0 }
      p50      = pct.call(sorted, 0.50)
      p95      = pct.call(sorted, 0.95)
      p99      = pct.call(sorted, 0.99)
      p999     = pct.call(sorted, 0.999)
      max_ms   = sorted.last * 1000.0

      # CPU build (frame minus present) and its share of the scene-graph draw.
      cpu_time    = cpu_times.sum
      cpu_avg_ms  = (cpu_time * 1000.0) / total
      cpu_fps     = cpu_time.positive? ? total / cpu_time : 0.0
      cpu_sorted  = cpu_times.sort
      present_avg_ms = ((total_time - cpu_time) * 1000.0) / total
      render_avg_ms  = (render_times.sum * 1000.0) / total
      render_p95_ms  = pct.call(render_times.sort, 0.95)

      puts format('  %-14s %s', 'Warmup:', "#{@warmup}s (#{warmup_frames} frames)")
      puts format('  %-14s %s', 'Measured:', "#{@duration}s (#{total} frames)")
      puts
      puts format('  %-14s %.1f fps  (%.2f ms/frame)', 'Throughput:', fps, avg_ms)
      puts
      puts '  Frame time (wall clock, incl. present):'
      puts format('    %-10s %.2f ms', 'p50:', p50)
      puts format('    %-10s %.2f ms', 'p95:', p95)
      puts format('    %-10s %.2f ms', 'p99:', p99)
      puts format('    %-10s %.2f ms', 'p99.9:', p999)
      puts format('    %-10s %.2f ms', 'max:', max_ms)
      puts
      puts '  CPU build (frame minus present) — the per-object cost:'
      puts format('    %-10s %.1f fps-equiv  (%.2f ms/frame)', 'throughput:', cpu_fps, cpu_avg_ms)
      puts format('    %-10s %.2f ms', 'p50:', pct.call(cpu_sorted, 0.50))
      puts format('    %-10s %.2f ms', 'p95:', pct.call(cpu_sorted, 0.95))
      puts format('    %-10s %.2f ms', 'p99:', pct.call(cpu_sorted, 0.99))
      puts format('    %-10s %.2f ms  (p95 %.2f ms)', 'render:', render_avg_ms, render_p95_ms)
      puts format('    %-10s %.2f ms', 'present:', present_avg_ms)
      puts

      # GC stats are CRuby-only (see `gc_available`); the web build omits them.
      if @gc_alloc_delta
        puts '  GC:'
        puts format('    %-12s %s objects (%s / frame)', 'Allocations:',
                    thousands(@gc_alloc_delta), thousands((@gc_alloc_delta.to_f / total).round))
        puts format('    %-12s %d', 'Minor GCs:', @gc_minor_delta)
        puts format('    %-12s %d', 'Major GCs:', @gc_major_delta)
      end
      puts '-' * 60
      puts
    end

    def thousands(n)
      sign = n.negative? ? '-' : ''
      "#{sign}#{n.abs.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}"
    end
  end
end
