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
        fonts = `find #{directory} -name *.ttf`.split("\n")
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
        if `uname`.include? 'Darwin'  # macOS
          '/Library/Fonts'
        elsif `uname`.include? 'Linux'
          '/usr/share/fonts'
        elsif `uname`.include? 'MINGW'
          'C:/Windows/Fonts'
        end
      end

    end

  end
end
