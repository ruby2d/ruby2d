# Ruby2D::Font

module Ruby2D
  # System-font discovery: list the available fonts, resolve a name to a file
  # path, and locate the bundled default. Font *files* are opened and cached
  # natively (see `R2D_FontCacheGet` in the C extension), keyed by path, size,
  # and style — there are no Ruby-side `Font` instances.
  class Font
    class << self
      # List all fonts, names only
      def all
        all_paths.map { |path| path.split('/').last.chomp('.ttf').downcase }.uniq.sort
      end

      # Find a font file path from its name (case-insensitive, matching `all`)
      def path(font_name)
        font_name = font_name.to_s.downcase
        # Match against the file's basename (as `all` computes names), not the
        # whole path — otherwise a directory component like 'fonts' matches.
        all_paths.find { |path| path.split('/').last.chomp('.ttf').downcase.include?(font_name) }
      end

      # Get full path to the default font
      def default
        if RUBY_ENGINE == 'mruby'
          # Native and WASM builds bundle fonts at ruby2d/fonts/ relative to the binary
          'ruby2d/fonts/outfit/outfit.ttf'
        else
          File.expand_path('../../assets/resources/fonts/outfit/outfit.ttf', __dir__)
        end
      end

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
        return [] unless directory

        if RUBY_ENGINE == 'mruby'
          # MRuby does not have `Dir` defined
          `find #{directory} -name *.ttf`.split("\n")
        else
          # If CRuby and/or non-Bash shell (like cmd.exe)
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
        @directory ||= OS_FONT_PATHS[host_os]
      end

      # Identify the host OS, mirroring AssetsTarget.host_os but returning a symbol.
      # Uses RbConfig when available (CRuby), falls back to uname (mruby).
      def host_os
        if Object.const_defined?(:RbConfig)
          host = RbConfig::CONFIG['host_os'].downcase
          return :windows if host.match?(/mswin|mingw|cygwin/)
          return :macos   if host.include?('darwin')
          return :linux   if host.include?('linux')
          return :openbsd if host.include?('openbsd')
        else
          uname = `uname`.strip
          return :macos   if uname.include?('Darwin')
          return :linux   if uname.include?('Linux')
          return :windows if uname.include?('MINGW')
          return :openbsd if uname.include?('OpenBSD')
        end
      rescue IOError
        nil
      end
    end
  end
end
