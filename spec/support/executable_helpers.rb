# Stand-in executables for the CLI lookup specs.

require_relative '../../assets/target'

# Write an empty executable named `name` in `dir` and return its path. What
# makes a file executable differs by platform: a mode bit on Unix, one of a
# few extensions on Windows, where `find_executable` tries them in turn and an
# extension-free `cc` is not something the system could run either.
def write_executable(dir, name)
  name += '.exe' if AssetsTarget.host_os == 'windows'
  path = File.join(dir, name)
  File.write(path, '')
  File.chmod(0o755, path)
  path
end
