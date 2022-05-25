# Ruby2D::Font

module Ruby2D
  class Font
    FONT_CACHE_LIMIT = 100

    @@loaded_fonts = {}

    attr_reader :ttf_font

    def initialize(path, size, style=nil)
      @ttf_font = Font.ext_load(path, size, style.to_s)
    end

    class << self
      def load(path, size, style=nil)
        unless File.exist? path
          raise Error, "Cannot find font file `#{path}`"
        end

        (@@loaded_fonts[[path, size, style]] ||= Font.new(path, size, style)).tap do |font|
          if @@loaded_fonts.size > FONT_CACHE_LIMIT
            @@loaded_fonts.shift
          end
        end
      end

      # List all fonts, names only
      def all
        all_paths.map { |path| path.split('/').last.chomp('.ttf').downcase }.uniq.sort
      end

      # Find a font file path from its name
      def path(font_name)
        all_paths.find { |path| path.downcase.include?(font_name) }
      end

      # Get all fonts with full file paths
      def all_paths
        # MRuby does not have `Dir` defined
        if RUBY_ENGINE == 'mruby'
          fonts = `find #{directory} -name *.ttf`.split("\n")
        # If MRI and/or non-Bash shell (like cmd.exe)
        else
          fonts = Dir["#{directory}/**/*.ttf"]
        end

        fonts = fonts.reject do |f|
          f.downcase.include?('bold')    ||
          f.downcase.include?('italic')  ||
          f.downcase.include?('oblique') ||
          f.downcase.include?('narrow')  ||
          f.downcase.include?('black')
        end

        fonts.sort_by { |f| f.downcase.chomp '.ttf' }
      end

      # Get the default font
      def default
        if $RUBY2D_PLATFORM == :wasm
          "#{Ruby2D.test_media}/bitstream_vera/vera.ttf"
        else
          if all.include? 'arial'
            path 'arial'
          else
            all_paths.first
          end
        end
      end

      # Get the fonts directory for the current platform
      def directory
        case $RUBY2D_PLATFORM
        when :macos
          '/Library/Fonts'
        when :linux
          '/usr/share/fonts'
        when :windows
          'C:/Windows/Fonts'
        when :bsd
          '/usr/X11R6/lib/X11/fonts'
        when :wasm
          ''
        end
      end
    end
  end
end
