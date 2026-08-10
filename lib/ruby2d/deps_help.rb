# Extension-free guidance for when Ruby 2D's native dependency, SDL3, isn't
# available. Shared by `ext/ruby2d/extconf.rb` (install time, when the extension
# can't link) and the native-load rescue in `ruby2d/core` (run time, when the
# extension was never built) — so the message is authored once and can't drift.
#
# `require_relative` (not `require`) so it resolves both at install time, when
# `lib/` isn't on the load path, and at run time, when it is.

require_relative 'cli/colorize'
require_relative '../../assets/target'

module Ruby2D
  module DepsHelp
    module_function

    # Detect the Linux distribution family from /etc/os-release.
    def linux_distro
      return :unknown unless File.exist?('/etc/os-release')

      ids = File.read('/etc/os-release')
                .scan(/^(?:ID|ID_LIKE)="?([^"\n]+)"?/)
                .flatten
                .flat_map(&:split)

      return :debian   if ids.any? { |id| %w[ubuntu debian linuxmint].include?(id) }
      return :fedora   if ids.any? { |id| %w[fedora rhel centos rocky almalinux].include?(id) }
      return :arch     if ids.any? { |id| %w[arch manjaro endeavouros].include?(id) }
      return :opensuse if ids.any? { |id| id.include?('suse') }

      :unknown
    end

    # The package-manager command that installs the SDL3 development libraries on
    # this platform, or nil when we can't name one (unknown Linux distro or BSD).
    def sdl3_install_command
      case AssetsTarget.host_os
      when 'macos'
        'brew install sdl3 sdl3_image sdl3_mixer sdl3_ttf'
      when 'windows'
        'pacman -S mingw-w64-ucrt-x86_64-SDL3 mingw-w64-ucrt-x86_64-SDL3_image mingw-w64-ucrt-x86_64-SDL3_mixer mingw-w64-ucrt-x86_64-SDL3_ttf'
      when 'linux'
        {
          debian:   'sudo apt install libsdl3-dev libsdl3-image-dev libsdl3-mixer-dev libsdl3-ttf-dev',
          fedora:   'sudo dnf install SDL3-devel SDL3_image-devel SDL3_mixer-devel SDL3_ttf-devel',
          arch:     'sudo pacman -S sdl3 sdl3_image sdl3_mixer sdl3_ttf',
          opensuse: 'sudo zypper install libSDL3-devel libSDL3_image-devel libSDL3_mixer-devel libSDL3_ttf-devel',
        }[linux_distro]
      when 'bsd'
        host = RbConfig::CONFIG['host_os'].downcase
        if    host.include?('freebsd') then 'sudo pkg install sdl3 sdl3_image sdl3_mixer sdl3_ttf'
        elsif host.include?('openbsd') then 'doas pkg_add sdl3 sdl3-image sdl3-mixer sdl3-ttf'
        elsif host.include?('netbsd')  then 'sudo pkgin install SDL3 SDL3_image SDL3_mixer SDL3_ttf'
        end
      end
    end

    # The two-path recovery notice, framed like the install banner. Either
    # install SDL3 with a package manager and rebuild with `gem pristine`, or
    # build the libraries locally with `ruby2d setup` (which rebuilds the
    # extension for you). Shown when no SDL3 — bundled, cached, or system — is
    # found, both at install time and when a Ruby 2D app is run before setup.
    def notice
      cmd = sdl3_install_command

      body = []
      body << "Ruby 2D installed, but its native extension isn't built —"
      body << "no SDL3 libraries were found for #{AssetsTarget.target_id}."
      body << ''
      body << 'To finish, choose one:'
      body << ''
      if cmd
        body << '• Install SDL3 with your package manager (easiest), then rebuild:'
        body << "    #{cmd.bold}"
        body << "    #{'gem pristine ruby2d'.bold}"
      else
        body << "• Install the SDL3 development libraries, then run #{'gem pristine ruby2d'.bold}"
      end
      body << ''
      body << '• Build the libraries locally (no system packages needed):'
      body << "    #{'ruby2d setup'.bold}"
      body << ''
      body << "See #{'ruby2d.com'.bold} for help."

      framed(body)
    end

    # The variant for system SDL3 that's present but older than Ruby 2D
    # requires. `ruby2d setup` leads here — the package manager that installed
    # the old version may not carry a new enough one yet.
    def notice_old_sdl(found = nil)
      version = found ? "is #{found}" : 'is too old'

      body = []
      body << "Ruby 2D installed, but its native extension isn't built —"
      body << "the system SDL3 #{version}, and Ruby 2D requires 3.4 or newer."
      body << ''
      body << 'To finish, choose one:'
      body << ''
      body << '• Build current libraries locally (no system packages needed):'
      body << "    #{'ruby2d setup'.bold}"
      body << ''
      body << '• Upgrade the SDL3 packages to 3.4+, then rebuild:'
      body << "    #{'gem pristine ruby2d'.bold}"
      body << ''
      body << "See #{'ruby2d.com'.bold} for help."

      framed(body)
    end

    # Frame a message body like the install banner.
    def framed(body)
      header = '== Ruby 2D: native extension not built '.ljust(70, '=')
      lines = ['', header, '', *body.map { |l| l.empty? ? '' : "  #{l}" }, '', '=' * 70, '']
      lines.join("\n")
    end
  end
end
