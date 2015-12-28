require 'rspec/core/rake_task'
require './lib/ruby2d/version'

task default: 'all'

def run_test(file)
  Rake::Task['build'].invoke
  Rake::Task['spec'].invoke
  system "( cd tests/ ; ruby #{file}.rb )"
end

desc "Run the specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "spec/*spec.rb"
end

desc "Build Gem"
task :build do
  puts "==> uninstall gem"
  system "gem uninstall ruby2d --executables"
  
  puts "==> build gem"
  system "gem build ruby2d.gemspec --verbose"
  
  puts "==> install gem"
  system "gem install ruby2d-#{Ruby2D::VERSION}.gem --local --verbose"
end

desc "Run testcard"
task :testcard do
  run_test 'testcard'
end

desc "Run input"
task :input do
  run_test 'input'
end

desc "Run controller"
task :controller do
  run_test 'controller'
end

desc "Test and build"
task :all do
  Rake::Task['build'].invoke
  Rake::Task['spec'].invoke
end
