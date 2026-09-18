require 'open3'
require 'tmpdir'
require 'fileutils'
require_relative '../assets/target'

# `ruby2d launch --native` hands the process over to the built app, so the
# app's exit status and console output are the command's own. Driven through
# the real CLI in a temporary project with a stand-in executable.
RSpec.describe 'ruby2d launch --native' do
  around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

  # The stand-in app is a shell script, which Windows can't run as `app.exe`;
  # only the missing-build path is checked there.
  def needs_shell_app
    skip 'the stand-in app is a shell script' if AssetsTarget.host_os == 'windows'
  end

  def write_app(script)
    exe = File.join(@dir, 'build/native/app')
    FileUtils.mkdir_p(File.dirname(exe))
    File.write(exe, "#!/bin/sh\n#{script}\n")
    File.chmod(0o755, exe)
  end

  def launch
    Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../lib', __dir__),
                    File.expand_path('../bin/ruby2d', __dir__), 'launch', '--native', chdir: @dir)
  end

  it 'exits with the status the app exits with' do
    needs_shell_app
    # Regression: the launcher returned `system`'s result and exited 0, so a
    # script or CI step never saw the app fail.
    write_app('exit 7')
    _, status = launch
    expect(status.exitstatus).to eq(7)
  end

  it 'passes the app output through' do
    needs_shell_app
    write_app('echo hello from the app')
    output, status = launch
    expect(output).to include('hello from the app')
    expect(status.exitstatus).to eq(0)
  end

  it 'runs the app from a project directory whose name has spaces and shell characters' do
    needs_shell_app
    # The path goes straight to `exec`, never through a shell: as one string
    # it was split at the space, or handed to `sh`, which choked on `(`.
    @dir = File.join(@dir, "My Game (v2) & Tom's")
    write_app('exit 7')
    output, status = launch
    expect(output).not_to include('sh:')
    expect(status.exitstatus).to eq(7)
  end

  it 'runs the app in the build directory' do
    needs_shell_app
    write_app('pwd')
    output, = launch
    expect(File.realpath(output.strip)).to eq(File.realpath(File.join(@dir, 'build/native')))
  end

  it 'ends the way the app does when a signal ends it' do
    needs_shell_app
    write_app('kill -TERM $$')
    _, status = launch
    expect(status.signaled?).to be true
    expect(status.termsig).to eq(Signal.list['TERM'])
  end

  it 'reports a missing build and exits 1' do
    output, status = launch
    expect(output).to include('No native app found')
    expect(status.exitstatus).to eq(1)
  end
end
