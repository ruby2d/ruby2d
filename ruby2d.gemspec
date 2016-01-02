$:.push File.expand_path('../lib', __FILE__)
require 'ruby2d/version'

Gem::Specification.new do |s|
  s.name        = 'ruby2d'
  s.version     = Ruby2D::VERSION
  s.date        = '2016-01-01'
  s.author      = 'Tom Black'
  s.email       = '@blacktm'
  s.summary     = 'Ruby 2D'
  s.description = 'Make cross-platform 2D applications in Ruby'
  s.homepage    = 'http://www.ruby2d.com'
  s.license     = 'MIT'
  s.files       = Dir.glob('lib/**/*') +
                  Dir.glob('assets/**/*') +
                  Dir.glob('ext/**/*.{c,rb}')
  s.extensions  = ['ext/ruby2d/extconf.rb']
  s.executables << 'ruby2d'
  s.required_ruby_version = '>= 2.0.0'
  s.add_development_dependency 'rspec', '~> 3.4'
end
