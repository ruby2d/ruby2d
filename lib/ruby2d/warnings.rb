module Ruby2D
  # Messages already emitted by `warn`, so a bad value produced every frame in a
  # render loop warns a single time rather than flooding the console. Keyed by
  # the message string.
  @warned_messages = {}

  # Emit a warning at most once per distinct message. Mirrors the native
  # extension's `R2D_Log(R2D_WARN, ...)`: a bold-yellow `[WARN]` tag (the same
  # `1;33` as the C side) followed by the message, on stderr — so Ruby and C
  # warnings render identically. `Kernel#warn` isn't available under mruby, so
  # write to `$stderr` directly.
  def self.warn(message)
    return if @warned_messages.key?(message)

    @warned_messages[message] = true
    $stderr.puts "\e[1;33m[WARN]\e[0m #{message}"
  end

  # Emit an informational diagnostic, mirroring the native extension's
  # `R2D_Log(R2D_INFO, ...)`: a bold-blue `[INFO]` tag (the same `1;34` as the
  # C side) followed by the message, on stderr. Like the C side, INFO is
  # suppressed unless diagnostics are enabled (`set(diagnostics: true)`) and —
  # unlike `warn` — it never dedupes, so every diagnostic event prints.
  def self.info(message)
    return unless DSL.window? && DSL.window.diagnostics

    $stderr.puts "\e[1;34m[INFO]\e[0m #{message}"
  end

  # An asset path made absolute, so it keeps naming the same file after the
  # working directory changes. `File.expand_path` reads a leading `~` as a
  # user's home directory and raises when there is no such user; a file or
  # directory literally named that way is then a relative path like any other.
  def self.absolute_path(path)
    return File.expand_path(path) unless path.start_with?('~')

    begin
      File.expand_path(path)
    rescue ArgumentError
      File.expand_path("./#{path}")
    end
  end
end
