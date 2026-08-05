require_relative 'browser'
require_relative 'colorize'

module Ruby2D
  module CLI
    module Examples

      EXAMPLES_DIR = File.expand_path('../../../examples', __dir__)

      # The gem root, where the bundled `assets/` directory sits alongside
      # `examples/`. Examples resolve asset paths relative to this — the same
      # relative layout `ruby2d build` mounts into the web VFS and copies into
      # the native bundle — so example runs `chdir` here (see `run`).
      ROOT_DIR = File.expand_path('..', EXAMPLES_DIR)

      # Parse the leading comment block from an example file. The convention
      # across `examples/*.rb` is:
      #
      #   # Title
      #   # Short description (one or two lines, shown in the picker preview).
      #   #
      #   # Longer narrative — controls, context, anything beyond the tagline.
      #
      # The short description (first paragraph after the title) becomes
      # `:description`; the entire post-title block becomes `:header`.
      def self.parse(path)
        title = nil
        header = []
        File.foreach(path) do |line|
          line = line.chomp
          break unless line.start_with?('#')
          stripped = line.sub(/^#\s?/, '')
          if title.nil?
            title = stripped unless stripped.empty?
            next
          end
          header << stripped
        end
        # Drop leading/trailing blank separator lines around the header block.
        header.shift while header.first == ''
        header.pop   while header.last  == ''
        # `description` is the first paragraph of the header, joined as one line.
        first_para = header.take_while { |l| !l.empty? }
        name = File.basename(path, '.rb')
        {
          name: name,
          title: title || name,
          description: first_para.join(' ').strip,
          header: header,
          path: path
        }
      end

      # Print the example's leading comment block (prose only, no title) in
      # dim text, indented to match the surrounding "Running …" message.
      def self.print_header(example)
        lines = example[:header]
        return if lines.nil? || lines.all?(&:empty?)
        lines.each { |line| puts(line.empty? ? '' : "  #{line.dim}") }
        puts
      end

      def self.all
        @all ||= Dir.glob("#{EXAMPLES_DIR}/*.rb").sort.map { |p| parse(p) }
      end

      def self.find(query)
        list = all
        if query.match?(/\A\d+\z/)
          idx = query.to_i
          # 1-based; out-of-range (incl. 0) returns nil rather than wrapping.
          return idx.between?(1, list.length) ? list[idx - 1] : nil
        end
        norm = ->(s) { s.downcase.tr('-_', ' ').delete("'").squeeze(' ').strip }
        q = norm.call(query)
        return nil if q.empty?  # an empty query must not match (and run) the first item

        list.find { |e| norm.call(e[:name]) == q || norm.call(e[:title]) == q } ||
          list.find { |e| norm.call(e[:name]).include?(q) || norm.call(e[:title]).include?(q) }
      end

      def self.run(example)
        # Run from `ROOT_DIR` so an example's relative asset paths (e.g.
        # `assets/resources/spritesheets`) resolve against the bundled assets.
        system(Gem.ruby, example[:path], chdir: ROOT_DIR)
      end

      # Non-interactive list, matching the style of `ruby2d usage`.
      def self.print_list
        list = all
        if list.empty?
          puts "\n  No examples found.\n\n"
          return
        end
        w = list.length.to_s.length
        puts "\n  #{'Ruby 2D'.ruby2d_red.bold} — Examples\n\n"
        list.each_with_index do |ex, i|
          puts "  #{(i + 1).to_s.rjust(w).dim}  #{ex[:title]}"
        end
        puts "\n  #{'ruby2d examples <name|number>'.dim}\n\n"
      end

      def self.browse
        list = all
        if list.empty?
          puts "\n  No examples found.\n\n"
          return
        end

        Browser.run(list: list, label: 'Examples', footer_action: 'run',
                    fallback: -> { print_list }) do |ex|
          puts
          puts "  #{'Ruby 2D'.ruby2d_red.bold} — Examples"
          puts
          puts "  Running #{ex[:title].bold} #{"(#{ex[:name]}.rb)".dim}"
          puts
          print_header(ex)
          ok = run(ex)
          unless ok
            print "\n  #{'Example exited with errors. Press Enter to continue…'.dim}"
            $stdin.gets
          end
        end
      end
    end
  end
end
