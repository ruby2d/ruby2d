require 'io/console'
require_relative 'colorize'

module Ruby2D
  module CLI
    # Generic interactive arrow-key TUI for browsing a list of items. Used by
    # both `ruby2d examples` and `ruby2d usage`. Items are hashes with at least
    # `:title` (shown in the list) and `:description` (shown beneath the list).
    module Browser

      RED   = "\e[38;2;246;60;56m"
      RESET = "\e[0m"
      BOLD  = "\e[1m"
      DIM   = "\e[2m"

      # Native-Windows Ruby (RubyInstaller) needs its own input handling: on some
      # builds `IO.console.raw` doesn't drop line/echo input, and even in raw
      # mode the console won't emit arrow keys as bytes unless virtual-terminal
      # input is on. `WinConsole` sets both directly; `read_key` then parses the
      # `\e[A`-style sequences that result. POSIX terminals are untouched.
      WINDOWS = Gem.win_platform?

      # Drives the Win32 console input mode through `SetConsoleMode`, because
      # native-Windows Ruby's `io/console` `raw` is unreliable here (confirmed on
      # `aarch64-mingw-ucrt`: `raw` left LINE/ECHO input enabled). Enabling
      # `VIRTUAL_TERMINAL_INPUT` is what makes arrow keys arrive as `\e[A`
      # sequences instead of being swallowed. All Fiddle use is lazy and
      # failure-tolerant: any problem returns nil and the caller falls back to
      # the plain `io/console` path.
      module WinConsole
        STD_INPUT_HANDLE = -10
        PROCESSED_INPUT  = 0x0001
        LINE_INPUT       = 0x0002
        ECHO_INPUT       = 0x0004
        VT_INPUT         = 0x0200

        # Lazily resolve the three kernel32 calls we need; memoize the result
        # (nil if Fiddle or the console API is unavailable).
        def self.api
          unless @resolved
            @resolved = true
            @api =
              begin
                require 'fiddle'
                k32 = Fiddle.dlopen('kernel32')
                {
                  get_handle: Fiddle::Function.new(k32['GetStdHandle'],   [Fiddle::TYPE_LONG], Fiddle::TYPE_VOIDP),
                  get_mode:   Fiddle::Function.new(k32['GetConsoleMode'],  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT),
                  set_mode:   Fiddle::Function.new(k32['SetConsoleMode'],  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG], Fiddle::TYPE_INT)
                }
              rescue LoadError, StandardError
                nil
              end
          end
          @api
        end

        # Switch the console to raw + virtual-terminal input. Returns the prior
        # mode (to hand back to `restore`), or nil when there's no console to set
        # (Fiddle missing, stdin redirected, `GetConsoleMode` failed).
        def self.enable_raw
          fns = api or return nil
          handle = fns[:get_handle].call(STD_INPUT_HANDLE)
          buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT, Fiddle::RUBY_FREE)
          return nil if fns[:get_mode].call(handle, buf) == 0
          prev = buf[0, Fiddle::SIZEOF_INT].unpack1('L')
          fns[:set_mode].call(handle, (prev & ~(LINE_INPUT | ECHO_INPUT | PROCESSED_INPUT)) | VT_INPUT)
          prev
        end

        # Re-apply raw + VT without disturbing the saved prior mode — used after
        # a child example returns, in case it left the shared console mode
        # changed.
        def self.reassert_raw
          enable_raw
        end

        def self.restore(prev)
          return if prev.nil?
          fns = api or return
          fns[:set_mode].call(fns[:get_handle].call(STD_INPUT_HANDLE), prev)
        end
      end

      # Run the interactive browser.
      #   list           array of item hashes with :title and :description
      #   label          header label, e.g. 'Examples' or 'Usage Guide'
      #   footer_action  verb after 'Enter to', e.g. 'run' or 'view'
      #   fallback       called when there is no usable TTY
      #   block          invoked with the selected item when Enter is pressed
      def self.run(list:, label:, footer_action:, fallback: nil, &on_select)
        return if list.empty?

        unless $stdout.tty? && IO.console
          fallback&.call
          return
        end

        selected = 0
        prev_mode = nil
        begin
          enter_alt_screen
          # On Windows, take over the console mode ourselves; `managed` is true
          # only when that succeeded (otherwise fall back to `io/console` raw).
          prev_mode = WinConsole.enable_raw if WINDOWS
          managed = !prev_mode.nil?
          # Managed mode reads IO.console directly; binmode stops Windows CRLF
          # read-translation from stalling Enter (it holds the CR of CR+LF
          # waiting to see whether an LF follows).
          IO.console.binmode if managed
          loop do
            render(list, selected, label, footer_action)
            case read_key(managed)
            when :up    then selected = (selected - 1) % list.length
            when :down  then selected = (selected + 1) % list.length
            when :pgup  then selected = [selected - 10, 0].max
            when :pgdn  then selected = [selected + 10, list.length - 1].min
            when :home  then selected = 0
            when :last  then selected = list.length - 1
            when :enter
              print "\e[2J\e[H\e[?25h\e[?1000l\e[?1006l"
              on_select.call(list[selected])
              # The example shared this console; re-assert our mode and drop
              # anything typed while it ran so stray keys (e.g. a queued Enter)
              # don't fire actions back in the picker.
              WinConsole.reassert_raw if managed
              IO.console.iflush if IO.console.respond_to?(:iflush)
              print "\e[?25l\e[?1000h\e[?1006h"
            when :quit
              break
            end
          end
        ensure
          WinConsole.restore(prev_mode) if WINDOWS
          leave_alt_screen
        end
      end

      # Enabling mouse-event reporting (1000 + 1006/SGR) stops most terminals
      # from translating the scroll wheel into arrow keys while the alt screen
      # is active. Mouse sequences are ignored in `read_key`.
      def self.enter_alt_screen
        print "\e[?1049h\e[?25l\e[?1000h\e[?1006h"
      end

      def self.leave_alt_screen
        print "\e[?1006l\e[?1000l\e[?1049l\e[?25h"
      end

      # Block for one keypress and map it to an action.
      # `managed` is true when `WinConsole` already put the console in raw + VT
      # input mode, so we read `IO.console` directly. Otherwise (POSIX, or
      # Windows without a settable console) we go through `io/console`'s `raw`.
      def self.read_key(managed = false)
        if managed
          read_console(IO.console)
        else
          IO.console.raw { |io| read_console(io) }
        end
      end

      # Classify one keypress from an already-raw stream. Windows and POSIX share
      # the single-byte keys and diverge only on how escape sequences are read:
      # POSIX's `read_escape_sequence` uses `IO.select`/`read_nonblock` (fine on
      # a pty), which native-Windows Ruby can't use on a console handle.
      def self.read_console(io)
        c = io.getc
        if    c.nil?                                   then :quit
        elsif WINDOWS && c == "\n"                     then nil  # LF half of CR+LF; the CR already fired :enter
        elsif (action = classify_char(c))             then action
        elsif WINDOWS && (c == "\x00" || c == "\xE0") then classify_scancode(io.getc)
        elsif c == "\e"
          classify_escape(WINDOWS ? read_escape_windows(io) : read_escape_sequence(io))
        end
      end

      # Single-byte keys, identical on every platform.
      def self.classify_char(c)
        case c
        when "\r", "\n"               then :enter
        when 'q', 'Q', "\x03", "\x04" then :quit
        when 'k'                      then :up
        when 'j'                      then :down
        when 'g'                      then :home
        when 'G'                      then :last
        end
      end

      # Legacy (non-VT) Windows consoles report arrows and navigation keys as two
      # bytes: a `\x00` or `\xE0` prefix, consumed by `read_console`, then the
      # scan code mapped here. With `VIRTUAL_TERMINAL_INPUT` on they arrive as
      # `\e[A` sequences instead, but this keeps the fallback working too.
      # (Left/Right are unused and fall through.)
      def self.classify_scancode(c)
        case c
        when 'H' then :up    # 0x48
        when 'P' then :down  # 0x50
        when 'I' then :pgup  # 0x49
        when 'Q' then :pgdn  # 0x51
        when 'G' then :home  # 0x47
        when 'O' then :last  # 0x4F (End)
        end
      end

      # Read a CSI/SS3 escape sequence on Windows without `IO.select` or
      # `read_nonblock` (unsupported on a console handle). An arrow key's whole
      # sequence lands in the input buffer at once, so a blocking `getc` returns
      # each following byte right away. A lone ESC has no follow-on byte and
      # would block here, so on Windows we quit with `q`, not ESC. If the byte
      # after ESC isn't a CSI/SS3 introducer we stop at once, swallowing nothing
      # extra.
      def self.read_escape_windows(io)
        seq = io.getc.to_s
        return seq unless seq == '[' || seq == 'O'
        14.times do
          c = io.getc
          break if c.nil?
          seq << c
          break if c.match?(/[A-Za-z~]/)
        end
        seq
      end

      # Read one CSI/SS3 escape sequence after the leading ESC. Waits briefly
      # for each byte so chunked delivery doesn't cut us short, and stops at
      # the first byte in the CSI final-byte range (0x40-0x7E).
      def self.read_escape_sequence(io)
        seq = ''
        32.times do
          break unless IO.select([io], nil, nil, 0.01)
          c = io.read_nonblock(1, exception: false)
          break if c.nil? || c == :wait_readable
          seq << c
          break if seq.length >= 2 && c.match?(/[A-Za-z~]/)
        end
        seq
      end

      def self.classify_escape(seq)
        return nil if seq.start_with?('[<') && seq.end_with?('M', 'm')  # SGR mouse
        return nil if seq.start_with?('[M')                              # X10 mouse
        case seq
        when ''                       then :quit  # bare ESC
        when '[A', 'OA'               then :up
        when '[B', 'OB'               then :down
        when '[H', '[1~', '[7~', 'OH' then :home
        when '[F', '[4~', '[8~', 'OF' then :last
        when '[5~'                    then :pgup
        when '[6~'                    then :pgdn
        end
      end

      def self.wrap(text, width)
        return [] if text.nil? || text.empty? || width <= 0
        lines = []
        current = ''
        text.split(' ').each do |word|
          if current.empty?
            current = word
          elsif current.length + 1 + word.length <= width
            current << ' ' << word
          else
            lines << current
            current = word
          end
        end
        lines << current unless current.empty?
        lines
      end

      def self.render(list, selected, label, footer_action)
        rows, cols = IO.console.winsize
        rows = 24 if rows.nil? || rows < 10
        cols = 80 if cols.nil? || cols < 40

        print "\e[2J\e[H"

        title = "  #{'Ruby 2D'.ruby2d_red.bold} — #{label} #{"(#{selected + 1}/#{list.length})".dim}"
        footer = "  #{"↑/↓ navigate · Enter to #{footer_action} · q to quit".dim}"
        desc_height = 3
        desc_lines = wrap(list[selected][:description], cols - 4)[0, desc_height]

        # 1 (blank) + title + 1 + viewport + 1 + desc_height + 1 + footer = rows
        viewport = rows - (5 + desc_height)
        viewport = [viewport, 5].max
        viewport = [viewport, list.length].min

        start = [selected - viewport / 2, 0].max
        start = [start, list.length - viewport].min
        start = 0 if start.negative?

        width = list.length.to_s.length

        puts
        puts title
        puts
        viewport.times do |i|
          idx = start + i
          item = list[idx]
          num = (idx + 1).to_s.rjust(width)
          if idx == selected
            puts "  #{RED}◆ #{BOLD}#{num}#{RESET}  #{RED}#{BOLD}#{item[:title]}#{RESET}"
          else
            puts "    #{DIM}#{num}#{RESET}  #{item[:title]}"
          end
        end
        puts
        desc_height.times { |i| puts "  #{DIM}#{desc_lines[i] || ''}#{RESET}" }
        puts
        print footer
      end
    end
  end
end
