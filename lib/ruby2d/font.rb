# Ruby2D::Font

module Ruby2D
  # System-font discovery: list the available fonts, resolve a name to a file
  # path, and locate the bundled default. Font *files* are opened and cached
  # natively (see `R2D_FontCacheGet` in the C extension), keyed by path, size,
  # and style — there are no Ruby-side `Font` instances.
  class Font
    # Font file types the native loader opens: TrueType, OpenType, and TrueType
    # collections (a `.ttc` opens at its first face).
    EXTENSIONS = %w[.ttf .otf .ttc].freeze

    # Style variants filed as their own files: a name containing one of these
    # is dropped, unless it says it is the regular face (`NotoSansOldItalic-
    # Regular`).
    STYLE_VARIANTS = %w[bold italic oblique narrow black].freeze

    # Font directories per platform: system-wide, then per-user. A leading `~`
    # expands when scanning; a directory that doesn't exist is skipped.
    OS_FONT_PATHS = {
      macos: ['/System/Library/Fonts', '/Library/Fonts', '~/Library/Fonts'],
      linux: ['/usr/share/fonts', '/usr/local/share/fonts', '~/.local/share/fonts', '~/.fonts'],
      windows: ['C:/Windows/Fonts', '~/AppData/Local/Microsoft/Windows/Fonts'],
      openbsd: ['/usr/X11R6/lib/X11/fonts', '/usr/local/share/fonts']
    }.freeze

    # Deepest directory nesting the scan follows below a font root. Real font
    # trees are a level or two deep.
    MAX_DEPTH = 8

    class << self
      # List all fonts, names only
      def all
        all_paths.map { |path| name_of(path) }.uniq.sort
      end

      # Find a font file path from its name (case-insensitive, matching `all`).
      # An exact name wins over a substring match, so `path('sans')` is the
      # font named "sans" and not whichever "…sans…" sorts first.
      def path(font_name)
        font_name = font_name.to_s.downcase
        all_paths.find { |path| name_of(path) == font_name } ||
          all_paths.find { |path| name_of(path).include?(font_name) }
      end

      # Get full path to the default font. Absolute on both runtimes, like the
      # `font` a `Text` reads back (see `Text#normalize_font_path`).
      def default
        if RUBY_ENGINE == 'mruby'
          # Native and WASM builds bundle fonts at ruby2d/fonts/ relative to the
          # working directory, which the native binary sets to its own location
          File.expand_path('ruby2d/fonts/outfit/outfit.ttf')
        else
          File.expand_path('../../assets/resources/fonts/outfit/outfit.ttf', __dir__)
        end
      end

      private

      # The name `all` lists a file under: its basename without the font
      # extension, downcased. Case-insensitive on the extension too, so an
      # `Arial.TTF` is "arial" and not "arial.ttf".
      def name_of(path)
        name = path.split('/').last.downcase
        EXTENSIONS.each do |ext|
          return name[0...-ext.length] if name.end_with?(ext)
        end
        name
      end

      # Get all fonts with full file paths
      def all_paths
        # memoize so we only calculate once
        @all_paths ||= platform_font_paths
      end

      # Compute and return all platform font file paths, removing variants by
      # style (judged on the file's name, not its directory), sorted by name
      def platform_font_paths
        fonts = find_os_font_files.reject do |f|
          name = name_of(f)
          !name.end_with?('regular') && STYLE_VARIANTS.any? { |variant| name.include?(variant) }
        end
        fonts.sort_by { |f| name_of(f) }
      end

      # Return all font files under the platform's font directories. A
      # hand-rolled walk over `Dir.entries` rather than a glob or a `find`
      # shell-out: mruby has no glob, and the shell expanded an unquoted
      # `*.ttf` against the working directory — beside a native executable,
      # the app's own font files became the pattern and system-font discovery
      # came back empty.
      def find_os_font_files
        files = []
        directories.each { |dir| collect_font_files(dir, 0, files) }
        files
      end

      # Append the font files under `dir` to `files`, recursing into
      # subdirectories (macOS keeps many under `Supplemental/`) but not into
      # symlinked ones, which a glob wouldn't follow either and which can loop.
      # A directory that can't be read contributes nothing rather than failing
      # the scan.
      def collect_font_files(dir, depth, files)
        Dir.entries(dir).each do |entry|
          next if entry == '.' || entry == '..'

          path = "#{dir}/#{entry}"
          if File.directory?(path)
            collect_font_files(path, depth + 1, files) if depth < MAX_DEPTH && !File.symlink?(path)
          elsif EXTENSIONS.any? { |ext| entry.downcase.end_with?(ext) }
            files << path
          end
        end
      rescue StandardError
        nil
      end

      # The platform's font directories that exist on this machine
      def directories
        @directories ||= (OS_FONT_PATHS[host_os] || []).map { |dir| expand_home(dir) }
                                                       .compact
                                                       .select { |dir| File.directory?(dir) }
      end

      # Expand a leading `~`. Returns nil when there is no home directory to
      # expand it against (`HOME` unset): a per-user directory can't exist then.
      def expand_home(dir)
        return dir unless dir.start_with?('~')

        File.expand_path(dir)
      rescue ArgumentError
        nil
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
