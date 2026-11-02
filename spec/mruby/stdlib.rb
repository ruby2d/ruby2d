# CRuby stand-ins

# What the specs lean on that mruby doesn't have. Like `regexp.rb`, this exists
# only in the spec build and the app shares it with `lib/`, so `lib/` must not
# start calling anything here: that would pass in the spec run and raise
# `NoMethodError` for real. Nothing in `lib/` does today.

# Everything is in the one compiled source file, so requires have nothing to do.
# These replace the `mruby_compat` versions, which refuse any library but Ruby 2D.
module Kernel
  def require(_name) = true
  def require_relative(_name) = true
end

module Ruby2D
  # `rake spec:native` and `rake spec:web` bundle `assets/test_media` as `media`.
  def self.test_media = File.expand_path('media')
  def self.test_audio = "#{test_media}/audio"
  def self.test_images = "#{test_media}/images"
  def self.test_spritesheets = "#{test_media}/spritesheets"
end

module AssetsTarget
  def self.host_os = File::ALT_SEPARATOR ? 'windows' : 'unix'
end

class File
  unless respond_to?(:write)
    def self.write(path, content)
      File.open(path, 'w') { |file| file.write(content) }
      content.length
    end
  end
end

class Dir
  TEMPORARY_DIRECTORIES = [0]

  def self.home = File.expand_path('~')

  def self.mktmpdir
    TEMPORARY_DIRECTORIES[0] += 1
    path = File.expand_path("spec_tmp_#{TEMPORARY_DIRECTORIES[0]}")
    FileUtils.remove_entry(path) if File.exist?(path)
    Dir.mkdir(path)
    return path unless block_given?

    begin
      yield path
    ensure
      FileUtils.remove_entry(path)
    end
  end
end

module FileUtils
  def self.mkdir(path) = Dir.mkdir(path)

  def self.mkdir_p(paths)
    [paths].flatten.each do |path|
      next if File.exist?(path)

      mkdir_p(File.dirname(path))
      Dir.mkdir(path)
    end
  end

  def self.cp(source, destination)
    data = File.open(source, 'rb') { |file| file.read }
    File.open(destination, 'wb') { |file| file.write(data) }
  end

  def self.remove_entry(path)
    if File.directory?(path) && !link?(path)
      Dir.entries(path).each do |entry|
        remove_entry(File.join(path, entry)) unless entry == '.' || entry == '..'
      end
      Dir.rmdir(path)
    else
      File.delete(path)
    end
  end

  # On Windows, mruby raises from `File.symlink?` and from `File.symlink`, so a
  # spec can't have made a link there.
  def self.link?(path)
    File.symlink?(path)
  rescue NotImplementedError
    false
  end
end

class Tempfile
  CREATED = [0]

  attr_reader :path

  def initialize(name = 'tmp')
    base, extension = name.is_a?(Array) ? name : [name, '']
    CREATED[0] += 1
    @path = File.expand_path("spec_#{base}_#{CREATED[0]}#{extension}")
    @file = File.open(@path, 'w')
  end

  def write(content) = @file.write(content)

  def flush
    @file.flush
    self
  end

  def close(_unlink = false)
    @file.close unless @file.closed?
    nil
  end

  def unlink
    File.delete(@path) if File.exist?(@path)
    nil
  end

  def close!
    close
    unlink
  end
end

class Pathname
  def self.pwd = new(Dir.getwd)

  def initialize(path)
    @path = path.to_s
  end

  def to_s = @path
  def to_path = @path
  def to_str = @path
  def ==(other) = other.is_a?(Pathname) && other.to_s == @path

  def relative_path_from(base)
    prefix = base.to_s.end_with?('/') ? base.to_s : "#{base}/"
    Pathname.new(@path.start_with?(prefix) ? @path[prefix.length..-1] : @path)
  end
end

# `Marshal.load(Marshal.dump(object))` is how the specs take a deep copy.
module Marshal
  def self.dump(object)
    case object
    when Array then object.map { |item| dump(item) }
    when Hash then object.each_with_object({}) { |(key, value), copy| copy[dump(key)] = dump(value) }
    when String then object.dup
    else object
    end
  end

  def self.load(copy) = copy
end

class Module
  def public_method_defined?(name) = instance_methods.include?(name)
end
