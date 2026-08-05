# `Ruby2D.warn` and `Ruby2D.info` are the Ruby-side counterparts to the native
# extension's `R2D_Log(R2D_WARN/R2D_INFO, ...)`: a colored `[WARN]`/`[INFO]` tag
# (sharing the C side's ANSI codes) followed by a message, on stderr. `warn`
# always prints but dedups per distinct message; `info` is gated behind
# diagnostics and never dedups. See `lib/ruby2d/warnings.rb`.
RSpec.describe 'Ruby2D logging' do
  # `warn`'s dedup cache lives on the Ruby2D module; reset it so each example
  # starts fresh (the suite's global before(:each) only resets DSL.window).
  before { Ruby2D.instance_variable_set(:@warned_messages, {}) }

  describe 'Ruby2D.warn' do
    it 'prints a bold-yellow [WARN] tag and the message to stderr' do
      expect { Ruby2D.warn 'bad thing' }.to output("\e[1;33m[WARN]\e[0m bad thing\n").to_stderr
    end

    it 'warns only once per distinct message' do
      expect { Ruby2D.warn 'dup' }.to output(/\[WARN\].*dup/).to_stderr
      expect { Ruby2D.warn 'dup' }.not_to output.to_stderr
    end

    it 'warns again for a different message' do
      expect { Ruby2D.warn 'one' }.to output(/one/).to_stderr
      expect { Ruby2D.warn 'two' }.to output(/two/).to_stderr
    end
  end

  describe 'Ruby2D.info' do
    it 'is silent when no window exists' do
      Ruby2D::DSL.window = nil
      expect { Ruby2D.info 'hi' }.not_to output.to_stderr
    end

    it 'is silent when a window exists but diagnostics are off' do
      Ruby2D::Window.new
      expect { Ruby2D.info 'hi' }.not_to output.to_stderr
    end

    it 'prints a bold-blue [INFO] tag and the message when diagnostics are on' do
      Ruby2D::Window.new
      Ruby2D::DSL.window.set(diagnostics: true)
      expect { Ruby2D.info 'hi' }.to output("\e[1;34m[INFO]\e[0m hi\n").to_stderr
    end

    it 'does not dedup — every diagnostic event prints' do
      Ruby2D::Window.new
      Ruby2D::DSL.window.set(diagnostics: true)
      expect { Ruby2D.info 'same'; Ruby2D.info 'same' }
        .to output("\e[1;34m[INFO]\e[0m same\n\e[1;34m[INFO]\e[0m same\n").to_stderr
    end
  end
end
