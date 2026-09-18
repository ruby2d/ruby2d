require 'ruby2d/cli/setup'
require 'ruby2d/cli/build'
require 'tmpdir'

RSpec.describe 'ruby2d/cli/setup helpers' do
  describe '#setup_command?' do
    it 'finds a command on PATH and misses one that is not' do
      expect(setup_command?('sh')).to be true
      expect(setup_command?('definitely-not-a-real-binary-xyz')).to be false
    end

    it 'accepts an explicit compiler path containing spaces, as the build does' do
      # Regression: the lookup shelled out to `command -v #{cmd}`, so a
      # `CC=/opt/tool chain/cc` was split at the space and reported missing
      # by `setup` while `ruby2d build --native` compiled with it.
      Dir.mktmpdir do |dir|
        tool_dir = File.join(dir, 'tool chain')
        Dir.mkdir(tool_dir)
        cc = write_executable(tool_dir, 'cc')
        expect(setup_command?(cc)).to be true
        expect(find_executable(cc)).to eq(cc)
      end
    end
  end
end
