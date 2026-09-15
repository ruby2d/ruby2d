# The `# ruby2d:assets <dir>` directive: an app's own bundling instructions,
# the flag-free equivalent of `--assets`. Read by `ruby2d build` (see
# cli/build) and by the examples rake tasks, which mirror the declared
# directories into a work dir before building. Extension-free, so the Rakefile
# can read directives before the gem is built.

require 'ripper'


# Collect the asset directories declared with `# ruby2d:assets <dir>` comments
# in the app source. One directory per directive; repeat the line for several.
# Paths are relative to the build's working directory, matching `--assets`.
# Only a comment declares one: the same text inside a string or heredoc (a
# printed help text, say) is the app's data, so the source is tokenized rather
# than matched line by line. Returns the directories in source order.
def asset_directives(file)
  Ripper.lex(File.read(file)).filter_map do |_pos, type, text, _state|
    next unless type == :on_comment

    # A stray non-UTF-8 byte in some other comment mustn't abort the scan.
    m = text.scrub.match(/\A#\s*ruby2d:assets\s+(\S.*?)\s*\z/)
    m && m[1]
  end
end
