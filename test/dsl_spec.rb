require 'ruby2d'
include Ruby2D::DSL

RSpec.describe Ruby2D::DSL do
  before do
    # Need to do this to ensure each test gets a clean DSL
    DSL.window = nil
  end

  describe '#initialize_once' do
    context 'first call' do
      before do
        initialize_once do |w|
          w.set title: 'Ruby 2D once'
        end
      end
      it 'succeeds' do
        expect(get(:title)).to eq('Ruby 2D once')
      end
    end
    context 'second attempt' do
      before do
        initialize_once do |w|
          w.set title: 'Ruby 2D once'
        end
      end
      it 'fails' do
        # second attempt should get ignored
        initialize_once do |w|
          w.set title: 'Ruby 2D twice'
        end
        expect(get(:title)).not_to eq('Ruby 2D twice')
      end
    end
  end

  describe '#get' do
    it 'gets the default window attributes' do
      expect(get(:width)).to eq(640)
      expect(get(:height)).to eq(480)
      expect(get(:title)).to eq('Ruby 2D')
    end
  end

  describe '#set' do
    it 'sets a single window attribute' do
      set width: 300
      expect(get(:width)).to eq(300)
      expect(get(:height)).to eq(480)
      expect(get(:title)).to eq('Ruby 2D')
    end

    it 'sets multiple window attributes at a time' do
      set width: 800, height: 600, title: 'Hello tests!'
      expect(get(:width)).to eq(800)
      expect(get(:height)).to eq(600)
      expect(get(:title)).to eq('Hello tests!')
    end
  end
end
