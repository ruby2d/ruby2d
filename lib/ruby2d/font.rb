# Ruby2D::Font

module Ruby2D
  class Font

    class << self

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
        if all.include? 'arial'
          path 'arial'
        else
          all_paths.first
        end
      end

      # Get the fonts directory for the current platform
      def directory
        macos_font_path   = '/Library/Fonts'
        linux_font_path   = '/usr/share/fonts'
        windows_font_path = 'C:/Windows/Fonts'

        # If MRI and/or non-Bash shell (like cmd.exe)
        if Object.const_defined? :RUBY_PLATFORM
          case RUBY_PLATFORM
          when /darwin/  # macOS
            macos_font_path
          when /linux/
            linux_font_path
          when /mingw/
            windows_font_path
          end
        # If MRuby
        else
          if `uname`.include? 'Darwin'  # macOS
            macos_font_path
          elsif `uname`.include? 'Linux'
            linux_font_path
          elsif `uname`.include? 'MINGW'
            windows_font_path
          end
        end
      end

    end

  end
end
