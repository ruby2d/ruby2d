require 'io/console'
require 'irb/color'
require_relative 'browser'
require_relative 'colorize'

module Ruby2D
  module CLI
    module Usage

      USAGE_PATH = File.expand_path('../../../USAGE.md', __dir__)

      def self.content
        @content ||= File.read(USAGE_PATH).sub(/^## Table of Contents\n(?:.*\n)*?\n(?=## )/, '')
      end

      def self.all
        @all ||= content.split(/^(?=## )/).select { |s| s[/^## /] }.map do |section|
          title = section[/^## (.+)/, 1]
          subs  = section.scan(/^### (.+)/).flatten
          {
            name: title.downcase.tr('-_', ' ').squeeze(' '),
            title: title,
            description: subs.join(' · '),
            content: section
          }
        end
      end

      def self.find(query)
        list = all
        if query.match?(/\A\d+\z/)
          idx = query.to_i
          # 1-based; out-of-range (incl. 0) returns nil rather than wrapping.
          return idx.between?(1, list.length) ? list[idx - 1] : nil
        end
        q = query.downcase.tr('-_', ' ').squeeze(' ')
        return nil if q.strip.empty?  # an empty query must not match the first item

        list.find { |s| s[:name] == q } || list.find { |s| s[:name].include?(q) }
      end

      # Pipe colorized markdown into `less`. `-R` passes ANSI colors through;
      # `-c` paints from the top (less's default scrolls up from the bottom,
      # which leaves short content awkwardly low); `--wordwrap` breaks long
      # lines at word boundaries. `-X` (`--no-init`) is added when invoked
      # from the TUI so less doesn't toggle its own alt screen — `\e[?1049l`
      # is binary, not nested, so without `-X` less's exit drops us out of
      # the TUI's alt screen onto the main screen.
      def self.view(section_or_text, tui: false)
        body = section_or_text.is_a?(Hash) ? section_or_text[:content] : section_or_text
        colored = colorize_markdown(body)
        flags = tui ? '-RcX' : '-Rc'
        flags += ' --wordwrap' if less_supports_wordwrap?
        begin
          IO.popen("less #{flags}", 'w') { |io| io.write(colored) }
        rescue Errno::EPIPE
          # user quit less before all content was written
        rescue Errno::ENOENT
          puts colored
        end
      end

      # `--wordwrap` (fold long lines at word boundaries) was added in less 581
      # (2021). Probe once; on older `less` we omit it and fall back to less's
      # default character-boundary folding rather than passing an unknown flag.
      def self.less_supports_wordwrap?
        return @less_supports_wordwrap unless @less_supports_wordwrap.nil?

        @less_supports_wordwrap = begin
          `less --help 2>/dev/null`.include?('--wordwrap')
        rescue StandardError
          false
        end
      end

      def self.print_list
        list = all
        if list.empty?
          puts "\n  No sections found.\n\n"
          return
        end
        w = list.length.to_s.length
        indent = ' ' * (w + 4)
        max_width = (IO.console&.winsize&.last || 80) - indent.length
        puts "\n  #{'Ruby 2D'.ruby2d_red.bold} — Usage Guide\n\n"
        list.each_with_index do |section, i|
          puts "  #{(i + 1).to_s.rjust(w).dim}  #{section[:title]}"
          subs = section[:content].scan(/^### (.+)/).flatten
          next if subs.empty?
          lines = []
          current = subs.first
          subs[1..].each do |sub|
            candidate = "#{current} · #{sub}"
            if candidate.length > max_width
              lines << current
              current = sub
            else
              current = candidate
            end
          end
          lines << current
          puts lines.map { |l| "#{indent}#{l.dim}" }.join("\n")
        end
        puts "\n  #{'ruby2d usage <name|number>'.dim}\n\n"
      end

      def self.browse
        list = all
        if list.empty?
          puts "\n  No sections found.\n\n"
          return
        end

        Browser.run(list: list, label: 'Usage Guide', footer_action: 'view',
                    fallback: -> { print_list }) do |section|
          view(section, tui: true)
        end
      end

      # Word-wrap plain text to a given width, returning an array of lines.
      def self.word_wrap(text, width)
        return [text] if text.length <= width
        lines, current = [], ''
        text.split(' ').each do |word|
          if current.empty?
            current = word
          elsif current.length + 1 + word.length <= width
            current += ' ' + word
          else
            lines << current
            current = word
          end
        end
        lines << current unless current.empty?
        lines
      end

      # Render a parsed markdown table with aligned columns and last-column wrapping.
      def self.render_table(rows, tw, bold, reset, gold)
        highlight = ->(text) { text.gsub(/`([^`]+)`/, "#{gold}`\\1`#{reset}") }

        col_widths = Array.new(rows.first.length, 0)
        rows.each do |row|
          row.each_with_index { |cell, i| col_widths[i] = [col_widths[i], cell.length].max }
        end

        prefix_width = col_widths[0..-2].sum + (col_widths.length - 1) * 3
        last_avail   = [tw - prefix_width, 20].max
        last_sep     = [col_widths.last, last_avail].min
        cont_prefix  = col_widths[0..-2].map { |w| ' ' * w }.join(' │ ') + ' │ '

        rows.each_with_index.map do |row, idx|
          non_last = row[0..-2].each_with_index.map do |cell, i|
            highlight.(cell) + ' ' * (col_widths[i] - cell.length)
          end

          chunks = word_wrap(row.last, last_avail)
          first  = highlight.(chunks.first || '')

          if idx == 0
            sep = (col_widths[0..-2] + [last_sep]).map { |w| '─' * w }.join('─┼─')
            "#{bold}#{(non_last + [first]).join(' │ ')}#{reset}\n#{sep}\n"
          else
            rest = chunks[1..].map { |chunk| "#{cont_prefix}#{highlight.(chunk)}\n" }.join
            "#{(non_last + [first]).join(' │ ')}\n#{rest}"
          end
        end.join
      end

      # Colorize Ruby code blocks and other markdown elements in a string.
      def self.colorize_markdown(content)
        bg    = "\e[48;5;234m"
        reset = "\e[0m"
        bold  = "\e[1m"
        dim   = "\e[2m"
        gold  = "\e[38;5;222m"

        tw = IO.console&.winsize&.last || 80

        in_block   = false
        block_lang = nil
        in_table   = false
        buffer     = []
        table_rows = []
        result     = []

        flush_table = lambda do
          result << render_table(table_rows, tw, bold, reset, gold) + "\n" unless table_rows.empty?
          table_rows = []
          in_table = false
        end

        # Render a code block's body with the background fill extended across
        # the full terminal width.
        emit_block_body = lambda do |body|
          body.each_line do |l|
            filled = l.chomp.gsub(reset, reset + bg)
            visible = l.chomp.gsub(/\e\[[0-9;]*m/, '').length
            result << "#{bg}#{filled}#{' ' * [tw - visible, 0].max}#{reset}\n"
          end
        end

        content.each_line do |line|
          if !in_block && line =~ /^\s*```(\S*)/
            flush_table.call if in_table
            in_block   = true
            block_lang = $1
            buffer     = []
            pad = ' ' * [tw - line.chomp.length, 0].max
            result << "#{bg}#{dim}#{line.chomp}#{reset}#{bg}#{pad}#{reset}\n"
          elsif line =~ /^\s*```/ && in_block
            body = if block_lang == 'ruby'
              IRB::Color.colorize_code(buffer.join, colorable: true)
            else
              buffer.join
            end
            emit_block_body.call(body)
            pad = ' ' * [tw - line.chomp.length, 0].max
            result << "#{bg}#{dim}#{line.chomp}#{reset}#{bg}#{pad}#{reset}\n"
            in_block   = false
            block_lang = nil
          elsif in_block
            buffer << line
          elsif line =~ /^\|/
            next if line =~ /^\|[-: |]+\|/  # skip separator rows
            in_table = true
            table_rows << line.split('|').map(&:strip).reject(&:empty?)
          else
            flush_table.call if in_table
            formatted = line.chomp
            formatted = formatted.gsub(/\[([^\]]+)\]\(([^)]+)\)/, "\e[4m\\1#{reset} #{dim}(\\2)#{reset}")
            formatted = formatted.gsub(/\*\*([^*]+)\*\*/, "#{bold}\\1#{reset}")
            formatted = formatted.gsub(/(?<!\w)\*(\S[^*\n]*?\S|\S)\*(?!\w)/, "\e[3m\\1#{reset}")
            formatted = formatted.gsub(/`([^`]+)`/, "#{gold}`\\1`#{reset}")
            if formatted =~ /^#+\s/
              # Bold the whole header line. Inline spans (code/links/emphasis)
              # inject their own resets that would cancel the bold mid-line, so
              # re-assert bold after each inner reset.
              formatted = "#{bold}#{formatted.gsub(reset, reset + bold)}#{reset}"
            end
            result << "#{formatted}\n"
          end
        end

        flush_table.call if in_table

        if in_block
          emit_block_body.call(buffer.join)
        end

        result.join
      end
    end
  end
end
