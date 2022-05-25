require 'rspec/core/rake_task'
require_relative 'lib/ruby2d/cli/colorize'
require_relative 'lib/ruby2d/cli/platform'
require_relative 'lib/ruby2d/version'

# Helpers ######################################################################

def get_args
  ARGV.each { |a| task a.to_sym do ; end }
end

def print_task(task)
  print "\n", "==> ".info, task.bold, "\n\n"
end

def run_cmd(cmd)
  puts "==> #{cmd}\n"
  system cmd
end

# Tasks ########################################################################

task default: 'all'

desc "Run default tasks using user-installed libraries"
task :dev do
  puts 'Building using user-installed libraries'.info
  $libs = '-- libs'
  Rake::Task['all'].invoke
end

desc "Uninstall gem"
task :uninstall do
  print_task "Uninstalling"
  run_cmd "gem uninstall ruby2d --executables"
end

desc "Build gem"
task :build do
  print_task "Building"
  run_cmd "gem build ruby2d.gemspec --verbose"
end

desc "Install gem"
task :install do
  print_task "Installing"
  run_cmd "gem install ruby2d-#{Ruby2D::VERSION}.gem --local --verbose #{$libs}"
end

desc "Update submodules"
task :update do
  run_cmd "git submodule update --remote"
end

desc "Run the RSpec tests"
RSpec::Core::RakeTask.new do |t|
  print_task "Running RSpec"
  t.pattern = "test/*spec.rb"
end

task :test => 'test:cruby'

namespace :test do
  desc "Run test using CRuby (MRI)"
  task :cruby do
    get_args
    test_file = ARGV[1]
    print_task "Running `#{test_file}.rb` with CRuby (MRI)"
    run_cmd "( cd test/ && ruby -w #{test_file}.rb )"
  end

  desc "An alias to CRuby"
  task :mri => :cruby

  desc "Run test using mruby"
  task :mruby do
    get_args
    test_file = ARGV[1]
    print_task "Running `#{test_file}.rb` with mruby"
    run_cmd "ruby2d build --clean"
    run_cmd "ruby2d build test/#{test_file}.rb --debug"
    run_cmd "( cd test/ && ../build/#{$RUBY2D_PLATFORM}/app )"
  end

  desc "Run test using WebAssembly"
  task :web do
    get_args
    test_file = ARGV[1]
    print_task "Running `#{test_file}.rb` with WebAssembly"

    run_cmd "ruby2d build --clean"
    result = run_cmd "ruby2d build test/#{test_file}.rb --assets assets/test_media --debug"
    unless result then exit(1) end

    run_cmd "ruby2d serve build/web/app.html"
  end

  desc "An alias to WebAssembly"
  task :wasm => :web
end

desc "Uninstall, build, install, and test"
task :all do
  Rake::Task['uninstall'].invoke
  Rake::Task['build'].invoke
  Rake::Task['install'].invoke
  Rake::Task['spec'].invoke
end
