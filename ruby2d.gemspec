require_relative 'lib/ruby2d/version'

Gem::Specification.new do |s|
  s.name        = 'ruby2d'
  s.version     = Ruby2D::VERSION
  s.summary     = 'Ruby 2D'
  s.description = 'Make cross-platform 2D applications in Ruby'
  s.homepage    = 'http://www.ruby2d.com'
  s.license     = 'MIT'
  s.author      = 'Tom Black'
  s.email       = 'tom@blacktm.com'

  s.required_ruby_version = '>= 2.7.0'
  s.add_development_dependency 'rake' , '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.12'
  s.add_development_dependency 'rubocop', '~> 1.42'
  s.files = Dir.glob('lib/**/*') +
            Dir.glob('ext/**/*.{h,c,rb}') +
            Dir.glob('assets/test_media/**/*')
  unless ARGV.include? 'dev'
    s.files += Dir.glob('assets/include/**/*') +
               Dir.glob('assets/macos/universal/**/*') +
               Dir.glob('assets/windows/**/*') +
               Dir.glob('assets/wasm/**/*') +
               Dir.glob('assets/xcode/**/*') +
               Dir.glob('assets/app.icns')
  end
  s.extensions = ['ext/ruby2d/extconf.rb']
  s.executables << 'ruby2d'
end
