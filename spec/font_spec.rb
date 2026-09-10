require 'fileutils'
require 'tmpdir'

# `Font.all` and `Font.path` list and resolve the fonts found by a scan of the
# platform's font directories. The scan itself is stubbed at
# `find_os_font_files` (or `directories`, to walk a temporary tree) so these
# run the same everywhere.
RSpec.describe Ruby2D::Font do
  # Bypass the memoized scan so each example's stub is what gets listed
  before { allow(Ruby2D::Font).to receive(:all_paths) { Ruby2D::Font.send(:platform_font_paths) } }

  describe '.path' do
    before do
      allow(Ruby2D::Font).to receive(:find_os_font_files)
        .and_return(['/Library/Fonts/Arial.ttf', '/Library/Fonts/Courier New.ttf'])
    end

    it 'matches regardless of the query case' do
      path = '/Library/Fonts/Arial.ttf'
      expect(Ruby2D::Font.path('arial')).to eq(path)
      expect(Ruby2D::Font.path('Arial')).to eq(path)
      expect(Ruby2D::Font.path('ARIAL')).to eq(path)
    end

    it 'matches on a substring' do
      expect(Ruby2D::Font.path('courier')).to eq('/Library/Fonts/Courier New.ttf')
    end

    it 'returns nil when nothing matches' do
      expect(Ruby2D::Font.path('Helvetica')).to be_nil
    end

    it 'prefers an exact name over a substring match that sorts first' do
      allow(Ruby2D::Font).to receive(:find_os_font_files)
        .and_return(['/f/Sans.ttf', '/f/Sans Mono.ttf', '/f/Open Sans.ttf'])
      expect(Ruby2D::Font.path('sans')).to eq('/f/Sans.ttf')
    end
  end

  describe '.all' do
    it 'lists TrueType, OpenType, and collection files by name, without the extension' do
      allow(Ruby2D::Font).to receive(:find_os_font_files).and_return(
        ['/System/Library/Fonts/SFNS.ttf', '/Library/Fonts/Arial.TTF',
         '/Library/Fonts/SF-Mono-Regular.otf', '/System/Library/Fonts/Helvetica.ttc']
      )
      expect(Ruby2D::Font.all).to eq(['arial', 'helvetica', 'sf-mono-regular', 'sfns'])
      expect(Ruby2D::Font.path('helvetica')).to eq('/System/Library/Fonts/Helvetica.ttc')
    end

    it 'drops style variants by file name, not by directory' do
      allow(Ruby2D::Font).to receive(:find_os_font_files).and_return(
        ['/Library/Fonts/Bold Choices/Plain.ttf', '/Library/Fonts/Arial Bold.ttf',
         '/Library/Fonts/Arial Italic.ttf', '/Library/Fonts/Arial.ttf']
      )
      expect(Ruby2D::Font.all).to eq(['arial', 'plain'])
    end
  end

  describe 'the directory scan' do
    it 'walks every configured directory recursively for font files of any case' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'Supplemental/deeper'))
        %w[A.ttf Supplemental/B.OTF C.ttc notes.txt Supplemental/deeper/D.ttf].each do |name|
          File.write(File.join(dir, name), '')
        end
        allow(Ruby2D::Font).to receive(:directories).and_return([dir])

        expect(Ruby2D::Font.all).to eq(%w[a b c d])
        expect(Ruby2D::Font.path('b')).to eq(File.join(dir, 'Supplemental/B.OTF'))
      end
    end

    it 'does not follow a symlinked directory, so a loop is walked once' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'One.ttf'), '')
        File.symlink(dir, File.join(dir, 'loop'))
        allow(Ruby2D::Font).to receive(:directories).and_return([dir])

        expect(Ruby2D::Font.send(:find_os_font_files)).to eq([File.join(dir, 'One.ttf')])
      end
    end

    it 'keeps a regular face whose family name contains a variant word' do
      allow(Ruby2D::Font).to receive(:find_os_font_files)
        .and_return(['/f/NotoSansOldItalic-Regular.ttf', '/f/NotoSansOldItalic-Bold.ttf'])
      expect(Ruby2D::Font.all).to eq(['notosansolditalic-regular'])
    end

    it 'skips a configured directory that is missing' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'Only.ttf'), '')
        allow(Ruby2D::Font).to receive(:directories).and_return([File.join(dir, 'missing'), dir])
        expect(Ruby2D::Font.all).to eq(['only'])
      end
    end

    it 'expands the home directory and keeps only directories that exist' do
      Ruby2D::Font.instance_variable_set(:@directories, nil)
      dirs = Ruby2D::Font.send(:directories)
      Ruby2D::Font.instance_variable_set(:@directories, nil)

      expect(dirs).to all(satisfy { |d| File.directory?(d) && !d.start_with?('~') })
    end
  end
end
