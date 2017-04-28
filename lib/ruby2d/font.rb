module Ruby2D
  class Font
    def self.all 
      all_full_paths
        .map{|path| path.split("/").last.delete(".ttf").downcase }
        .uniq
        .sort
    end

    def self.find_path(font_name)
      all_full_paths.find{|path| path.include?(font_name) }
    end

    def self.all_full_paths
      Dir["#{fonts_directory}**/*"]
        .keep_if{|path| !path.downcase.include?("bold")}
        .keep_if{|path| !path.downcase.include?("italic")}
        .keep_if{|path| !path.downcase.include?("oblique")}
        .keep_if{|path| path.include?("ttf")}
    end

    def self.default
      if RUBY_ENGINE == 'opal'
        nil
      else
        if all.include?("arial")
          find_path("arial")
        else
          all_full_paths.first
        end
      end
    end

    def self.fonts_directory
      if RUBY_PLATFORM =~ /darwin/
        "/Library/Fonts/"
      else
        "/usr/share/fonts/truetype/"
      end
    end
  end
end
