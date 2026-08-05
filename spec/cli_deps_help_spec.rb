require 'ruby2d/deps_help'

# The recovery guidance shown when SDL3 isn't available — authored once in
# DepsHelp and used by both extconf (install time) and the native-load rescue
# in ruby2d/core (run time). Locks the message's key contents so neither path
# can silently lose them.
RSpec.describe Ruby2D::DepsHelp do
  describe '.notice' do
    let(:notice) { described_class.notice }

    it 'names both recovery paths' do
      expect(notice).to include('ruby2d setup')
      expect(notice).to include('gem pristine ruby2d')
    end

    it 'names the platform that has no libraries' do
      expect(notice).to include(AssetsTarget.target_id)
    end
  end

  describe '.sdl3_install_command' do
    it 'returns a package-manager command string or nil' do
      expect(described_class.sdl3_install_command).to be_a(String).or be_nil
    end

    it 'names SDL3 when it returns a command' do
      cmd = described_class.sdl3_install_command
      skip 'no package-manager command for this platform' if cmd.nil?
      expect(cmd.downcase).to include('sdl3')
    end
  end

  describe '.linux_distro' do
    it 'returns a symbol' do
      expect(described_class.linux_distro).to be_a(Symbol)
    end
  end
end
