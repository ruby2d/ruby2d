# Locate an executable. Shared by `ruby2d build` (the C compiler, `emcc`,
# `mrbc`) and `ruby2d setup`'s preflight (git, cmake, the compiler), so a
# `CC=…` value means the same thing to both. Extension-free, like the rest of
# the CLI (see `bin/ruby2d`).

require_relative '../../../assets/target'


# Locate an executable on PATH. Portable replacement for `which`, which is
# Unix-only (Windows cmd.exe has no `which`); tries Windows executable
# extensions when running there. Returns the path, or nil.
def find_executable(name)
  exts = AssetsTarget.host_os == 'windows' ? ['.exe', '.bat', '.cmd', ''] : ['']

  # An explicit path (e.g. `CC=/usr/bin/clang`) is used as-is, not searched on
  # PATH — `File.join(dir, '/usr/bin/clang')` would collapse to a bogus path.
  if name.include?(File::SEPARATOR) || (File::ALT_SEPARATOR && name.include?(File::ALT_SEPARATOR))
    exts.each do |ext|
      candidate = "#{name}#{ext}"
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end
    return nil
  end

  ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
    next if dir.empty?
    exts.each do |ext|
      candidate = File.join(dir, "#{name}#{ext}")
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end
  end
  nil
end
