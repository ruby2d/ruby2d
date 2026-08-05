require_relative 'lib/ruby2d/version'

Gem::Specification.new do |s|
  s.name        = 'ruby2d'
  s.version     = Ruby2D::VERSION
  s.summary     = 'Make 2D applications with Ruby'
  s.description = "Ruby 2D is a library for creating 2D applications, games, graphics, "   \
                  "and interactive art in a way that's simple, natural, and joyful, in "   \
                  "the spirit of Ruby itself. The same code can run as an interpreted "    \
                  "Ruby app, a native executable on macOS, Windows, and Linux, or a web "  \
                  "app in the browser, with hardware-accelerated rendering, audio, text, " \
                  "sprites, and gamepad support."
  s.homepage    = 'https://www.ruby2d.com'
  s.license     = 'MIT'
  s.author      = 'Tom Black'
  s.email       = 'hello@ruby2d.com'

  s.metadata = {
    'homepage_uri' => 'https://www.ruby2d.com',
    'source_code_uri' => 'https://github.com/ruby2d/ruby2d',
    'bug_tracker_uri' => 'https://github.com/ruby2d/ruby2d/issues',
    'changelog_uri' => 'https://github.com/ruby2d/ruby2d/releases',
    'documentation_uri' => 'https://www.ruby2d.com/learn/',
    'mailing_list_uri' => 'https://groups.google.com/g/ruby2d',
    'rubygems_mfa_required' => 'true'
  }

  s.required_ruby_version = '>= 4.0'
  s.add_development_dependency 'rspec', '~> 3.13'
  s.files = ['USAGE.md', 'README.md', 'LICENSE.md'] +
            Dir.glob('lib/**/*') +
            Dir.glob('ext/**/*.{h,c,rb}') +
            Dir.glob('assets/platform/**/*') +
            Dir.glob('assets/resources/**/*') +
            Dir.glob('assets/Rakefile') +
            Dir.glob('assets/target.rb') +
            Dir.glob('assets/deps.yaml') +
            Dir.glob('assets/build_support/**/*') +
            Dir.glob('examples/*.rb')
  s.extensions = ['ext/ruby2d/extconf.rb']
  s.executables << 'ruby2d'
end
