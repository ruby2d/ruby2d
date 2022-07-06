# frozen_string_literal: true

# Ruby2D::Font

module Ruby2D
  #
  # Font represents a single typeface in a specific size and style.
  # Use +Font.load+ to load/retrieve a +Font+ instance by path, size and style.
  class Font
    FONT_CACHE_LIMIT = 100

    attr_reader :ttf_font

    # Cache loaded fonts in a class variable
    @loaded_fonts = {}

    class << self
      # Return a font by +path+, +size+ and +style+, loading the font if not already in the cache.
      #
      # @param path [#to_s] Full path to the font file
      # @param size [Numeric] Size of font to setup
      # @param style [String] Font style
      #
      # @return [Font]
      def load(path, size, style = nil)
        path = path.to_s
        raise Error, "Cannot find font file `#{path}`" unless File.exist? path

        (@loaded_fonts[[path, size, style]] ||= Font.send(:new, path, size, style)).tap do |_font|
          @loaded_fonts.shift if @loaded_fonts.size > FONT_CACHE_LIMIT
        end
      end

      # List all fonts, names only
      def all
        all_paths.map { |path| path.split('/').last.chomp('.ttf').downcase }.uniq.sort
      end

      # Find a font file path from its name, if it exists in the platforms list of fonts
      # @return [String] full path if +font_name+ is known
      # @return [nil] if +font_name+ is unknown
      def path(font_name)
        all_paths.find { |path| path.downcase.include?(font_name) }
      end

      # Get full path to the default font
      def default
        if all.include? 'arial'
          path 'arial'
        else
          all_paths.first
        end
      end

      # Font cannot be instantiated directly; use +Font.load+ instead.
      private :new

      private

      # Get all fonts with full file paths
      def all_paths
        # memoize so we only calculate once
        @all_paths ||= platform_font_paths
      end

      # Compute and return all platform font file paths, removing variants by style
      def platform_font_paths
        fonts = find_os_font_files.reject do |f|
          f.downcase.include?('bold') ||
            f.downcase.include?('italic')  ||
            f.downcase.include?('oblique') ||
            f.downcase.include?('narrow')  ||
            f.downcase.include?('black')
        end
        fonts.sort_by { |f| f.downcase.chomp '.ttf' }
      end

      # Return all font files in the platform's font location
      def find_os_font_files
        if RUBY_ENGINE == 'mruby'
          # MRuby does not have `Dir` defined
          `find #{directory} -name *.ttf`.split("\n")
        else
          # If MRI and/or non-Bash shell (like cmd.exe)
          Dir["#{directory}/**/*.ttf"]
        end
      end

      # Mapping of OS names to platform-specific font file locations
      OS_FONT_PATHS = {
        macos: '/Library/Fonts',
        linux: '/usr/share/fonts',
        windows: 'C:/Windows/Fonts',
        openbsd: '/usr/X11R6/lib/X11/fonts'
      }.freeze

      # Get the fonts directory for the current platform
      def directory
        # If MRI and/or non-Bash shell (like cmd.exe)
        # memoize so we only calculate once
        @directory ||= OS_FONT_PATHS[ruby_platform_osname || sys_uname_osname]
      end

      # Uses RUBY_PLATFORM to identify OS
      def ruby_platform_osname
        return unless Object.const_defined? :RUBY_PLATFORM

        case RUBY_PLATFORM
        when /darwin/ # macOS
          :macos
        when /linux/
          :linux
        when /mingw/
          :windows
        when /openbsd/
          :openbsd
        end
      end

      # Uses uname command to identify OS
      def sys_uname_osname
        uname = `uname`
        if uname.include? 'Darwin' # macOS
          :macos
        elsif uname.include? 'Linux'
          :linux
        elsif uname.include? 'MINGW'
          :windows
        elsif uname.include? 'OpenBSD'
          :openbsd
        end
      end
    end

    # Private constructor, called internally using +Font.send(:new,...)+
    def initialize(path, size, style = nil)
      @ttf_font = Font.ext_load(path.to_s, size, style.to_s)
    end
  end
end
