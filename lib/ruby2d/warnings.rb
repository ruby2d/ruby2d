module Ruby2D
  # Messages already emitted by `warn`, so a bad value produced every frame in a
  # render loop warns a single time rather than flooding the console. Keyed by
  # the message string.
  @warned_messages = {}

  # Emit a warning at most once per distinct message. Mirrors the native
  # extension's `R2D_Log(R2D_WARN, ...)`: a bold-yellow `[WARN]` tag
  # (`String#warning` shares the C side's `1;33`) followed by the message, on
  # stderr — so Ruby and C warnings render identically. `Kernel#warn` isn't
  # available under mruby, so write to `$stderr` directly.
  def self.warn(message)
    return if @warned_messages.key?(message)

    @warned_messages[message] = true
    $stderr.puts "#{'[WARN]'.warning} #{message}"
  end

  # Emit an informational diagnostic, mirroring the native extension's
  # `R2D_Log(R2D_INFO, ...)`: a bold-blue `[INFO]` tag (`String#info` and the C
  # side both use `1;34`) followed by the message, on stderr. Like the C side,
  # INFO is suppressed unless diagnostics are enabled (`set(diagnostics: true)`)
  # and — unlike `warn` — it never dedupes, so every diagnostic event prints.
  def self.info(message)
    return unless DSL.window? && DSL.window.diagnostics

    $stderr.puts "#{'[INFO]'.info} #{message}"
  end
end
