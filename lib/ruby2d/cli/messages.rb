# Ruby 2D CLI messages
#
# The `Error:` / `Warning:` / `Note:` lines shared by the `ruby2d` CLI, `rake`,
# and the build scripts. The label carries the color and the message stays
# normal weight, so the eye lands on the label first.
#
# Kept out of `LIB_FILES` (see `lib_files.rb`) on purpose: these write to a
# terminal, and compiling them into every native and web app would ship CLI-only
# code inside a user's game.

require_relative 'colorize'

# Compose a labeled line. `spaced` adds a blank line above, for a message that
# interrupts a run of build output; `indent` matches the nesting of the output
# around it (task bodies indent their results by four).
#
# The `ruby2d_` prefix keeps this clear of `mkmf`'s own `message`, which is in
# scope while `extconf.rb` runs.
def ruby2d_labeled(label, msg, spaced, indent)
  "#{"\n" if spaced}#{' ' * indent}#{label} #{msg}"
end

def error(msg, spaced: false, indent: 0)
  puts ruby2d_labeled('Error:'.error, msg, spaced, indent)
end

def warning(msg, spaced: false, indent: 0)
  puts ruby2d_labeled('Warning:'.warning, msg, spaced, indent)
end

def note(msg, spaced: false, indent: 0)
  puts ruby2d_labeled('Note:'.bold, msg, spaced, indent)
end

# Print an `Error:` line and exit non-zero. Writes to stderr rather than stdout,
# and never returns — so it also reads correctly as the right-hand side of
# `system(cmd) || abort_error(...)`.
def abort_error(msg, spaced: false, indent: 0)
  abort ruby2d_labeled('Error:'.error, msg, spaced, indent)
end
