# Regexp

# mruby has no Regexp, so the specs' regex literals would raise `NameError`. This
# is a small backtracking engine covering what they use: literals, classes,
# groups, alternation, greedy and lazy quantifiers, anchors, and the `i` and `m`
# flags.
#
# It exists only in the spec build, and the app shares it with `lib/`. A regex in
# `lib/` would pass here and crash for real, since no shipped build has Regexp.
# There are none on an mruby path today: `Font.host_os` has the one literal, on
# its `RbConfig` branch.
class Regexp
  IGNORECASE = 1
  EXTENDED = 2
  MULTILINE = 4

  attr_reader :source, :options

  # What mruby compiles a regex literal into a call to.
  def self.compile(source, options = nil, _encoding = nil) = new(source, options)

  def self.escape(string)
    string.to_s.chars.map { |c| '.*?+^$|\\()[]{}-/'.include?(c) ? "\\#{c}" : c }.join
  end

  def initialize(source, options = nil)
    @source = source.is_a?(Regexp) ? source.source : source.to_s
    @options = parse_options(options)
    @ignore_case = (@options & IGNORECASE) != 0
    @dot_matches_newline = (@options & MULTILINE) != 0
    @pattern = @source.chars
    @position = 0
    @group_count = 0
    @tree = parse_alternatives
  end

  def to_s = @source
  def inspect = "/#{@source}/"
  def ==(other) = other.is_a?(Regexp) && other.source == @source && other.options == @options
  def ===(value) = (value.is_a?(String) || value.is_a?(Symbol)) && match?(value.to_s)
  def match?(string) = !string.nil? && !match(string.to_s).nil?

  def =~(string)
    return nil if string.nil?

    found = match(string.to_s)
    found ? found.begin(0) : nil
  end

  def match(string, start = 0)
    return nil if string.nil?

    @chars = string.to_s.chars
    @length = @chars.length
    start.upto(@length) do |from|
      @captures = {}
      to = match_node(@tree, from, ->(position) { position })
      return MatchData.new(@chars, from, to, @captures, @group_count) if to
    end
    nil
  end

  class MatchData
    def initialize(chars, from, to, captures, group_count)
      @chars = chars
      @from = from
      @to = to
      @captures = captures
      @group_count = group_count
    end

    def begin(group) = group == 0 ? @from : (@captures[group] && @captures[group][0])

    def [](group)
      range = group == 0 ? [@from, @to] : @captures[group]
      range ? @chars[range[0]...range[1]].join : nil
    end

    def captures = (1..@group_count).map { |group| self[group] }
    def pre_match = @chars[0...@from].join
    def post_match = @chars[@to..-1].join
    def to_s = self[0]
  end

  private

  def parse_options(options)
    case options
    when Integer then options
    when true then IGNORECASE
    when String
      flags = 0
      flags |= IGNORECASE if options.include?('i')
      flags |= MULTILINE if options.include?('m')
      flags |= EXTENDED if options.include?('x')
      flags
    else 0
    end
  end

  # Parsing: the pattern becomes a tree of [type, ...] arrays.

  def peek = @pattern[@position]

  def take
    char = @pattern[@position]
    @position += 1
    char
  end

  def parse_alternatives
    alternatives = [parse_sequence]
    while peek == '|'
      take
      alternatives << parse_sequence
    end
    alternatives.length == 1 ? alternatives[0] : [:alternatives, alternatives]
  end

  def parse_sequence
    items = []
    items << parse_quantifier(parse_atom) while @position < @pattern.length && peek != '|' && peek != ')'
    [:sequence, items]
  end

  def digit?(char) = !char.nil? && char >= '0' && char <= '9'

  def word?(char)
    return false if char.nil?

    digit?(char) || (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') || char == '_'
  end

  def space?(char) = [' ', "\t", "\n", "\r", "\f", "\v"].include?(char)

  def parse_quantifier(atom)
    case peek
    when '*' then take; repeat(atom, 0, nil)
    when '+' then take; repeat(atom, 1, nil)
    when '?' then take; repeat(atom, 0, 1)
    when '{' then parse_counted_quantifier(atom)
    else atom
    end
  end

  # `{2}`, `{2,}`, `{2,4}`, or `{,4}`; a `{` that isn't one of those is literal.
  def parse_counted_quantifier(atom)
    start = @position
    take
    min = take_digits
    max = min
    if peek == ','
      take
      max = take_digits
    end
    if peek == '}' && !(min.empty? && max.empty?)
      take
      return repeat(atom, min.empty? ? 0 : min.to_i, max.empty? ? nil : max.to_i)
    end

    @position = start + 1
    [:sequence, [atom, [:char, '{']]]
  end

  def take_digits
    digits = ''
    digits += take while digit?(peek)
    digits
  end

  def repeat(atom, min, max)
    greedy = peek != '?'
    take if peek == '?'
    [:repeat, atom, min, max, greedy]
  end

  def parse_atom
    case char = take
    when '.' then [:any]
    when '^' then [:line_start]
    when '$' then [:line_end]
    when '[' then parse_class
    when '(' then parse_group
    when '\\' then parse_escape
    else [:char, char]
    end
  end

  def parse_group
    if peek == '?'
      take
      kind = take
      raise "unsupported group (?#{kind}" unless kind == ':'

      inner = parse_alternatives
      take
      return inner
    end

    @group_count += 1
    index = @group_count
    inner = parse_alternatives
    take
    [:group, index, inner]
  end

  def parse_escape
    case char = take
    when 'A' then [:string_start]
    when 'z' then [:string_end]
    when 'Z' then [:string_end_before_newline]
    when 'b' then [:word_boundary]
    when 'd' then [:class, false, [[:digit]]]
    when 'D' then [:class, true, [[:digit]]]
    when 'w' then [:class, false, [[:word]]]
    when 'W' then [:class, true, [[:word]]]
    when 's' then [:class, false, [[:space]]]
    when 'S' then [:class, true, [[:space]]]
    when 'n' then [:char, "\n"]
    when 't' then [:char, "\t"]
    when 'e' then [:char, "\e"]
    else [:char, char]
    end
  end

  def parse_class
    negated = peek == '^'
    take if negated
    items = []
    first = true
    while @position < @pattern.length && (peek != ']' || first)
      first = false
      items << parse_class_item
    end
    take
    [:class, negated, items]
  end

  def parse_class_item
    char = take
    return parse_class_escape if char == '\\'
    return char unless peek == '-' && @position + 1 < @pattern.length && @pattern[@position + 1] != ']'

    take
    high = take
    high = take if high == '\\'
    [:range, char, high]
  end

  def parse_class_escape
    case char = take
    when 'd' then [:digit]
    when 'w' then [:word]
    when 's' then [:space]
    when 'n' then "\n"
    when 't' then "\t"
    else char
    end
  end

  # Matching: each node takes the position and a continuation for the rest of
  # the pattern, so backtracking is the continuation returning nil. A match
  # returns the position it ended at.

  def same_char?(a, b)
    a == b || (@ignore_case && a.downcase == b.downcase)
  end

  def in_range?(char, low, high)
    return true if char >= low && char <= high
    return false unless @ignore_case

    (char.downcase >= low && char.downcase <= high) || (char.upcase >= low && char.upcase <= high)
  end

  def class_item_matches?(item, char)
    return same_char?(item, char) if item.is_a?(String)

    case item[0]
    when :digit then digit?(char)
    when :word then word?(char)
    when :space then space?(char)
    when :range then in_range?(char, item[1], item[2])
    end
  end

  def single_char_node?(node) = %i[char any class].include?(node[0])

  def node_matches_char?(node, char)
    case node[0]
    when :char then same_char?(node[1], char)
    when :any then @dot_matches_newline || char != "\n"
    else
      found = node[2].any? { |item| class_item_matches?(item, char) }
      node[1] ? !found : found
    end
  end

  def match_node(node, at, rest)
    case node[0]
    when :char, :any, :class
      at < @length && node_matches_char?(node, @chars[at]) ? rest.call(at + 1) : nil
    when :sequence then match_sequence(node[1], 0, at, rest)
    when :alternatives then match_alternatives(node[1], at, rest)
    when :repeat then match_repeat(node, 0, at, rest)
    when :group then match_group(node, at, rest)
    else assertion_holds?(node[0], at) ? rest.call(at) : nil
    end
  end

  def assertion_holds?(type, at)
    case type
    when :string_start then at == 0
    when :string_end then at == @length
    when :string_end_before_newline then at == @length || (at == @length - 1 && @chars[at] == "\n")
    when :line_start then at == 0 || @chars[at - 1] == "\n"
    when :line_end then at == @length || @chars[at] == "\n"
    when :word_boundary
      (at > 0 && word?(@chars[at - 1])) != (at < @length && word?(@chars[at]))
    end
  end

  def match_sequence(items, index, at, rest)
    return rest.call(at) if index >= items.length

    match_node(items[index], at, ->(position) { match_sequence(items, index + 1, position, rest) })
  end

  def match_alternatives(alternatives, at, rest)
    alternatives.each do |alternative|
      result = match_node(alternative, at, rest)
      return result if result
    end
    nil
  end

  def match_group(node, at, rest)
    index = node[1]
    match_node(node[2], at, lambda { |position|
      saved = @captures[index]
      @captures[index] = [at, position]
      result = rest.call(position)
      @captures[index] = saved unless result
      result
    })
  end

  def match_repeat(node, count, at, rest)
    _, atom, min, max, greedy = node
    return match_single_char_repeat(atom, min, max, greedy, at, rest) if single_char_node?(atom)

    again = ->(position) { position == at ? nil : match_repeat(node, count + 1, position, rest) }
    may_repeat = max.nil? || count < max
    if greedy
      result = match_node(atom, at, again) if may_repeat
      return result if result

      return count >= min ? rest.call(at) : nil
    end

    if count >= min
      result = rest.call(at)
      return result if result
    end
    may_repeat ? match_node(atom, at, again) : nil
  end

  # A repeated single character needs no recursion, which keeps a long `.*` from
  # exhausting the stack.
  def match_single_char_repeat(atom, min, max, greedy, at, rest)
    position = at
    count = 0
    consume = lambda do
      return false if !max.nil? && count >= max
      return false unless position < @length && node_matches_char?(atom, @chars[position])

      position += 1
      count += 1
      true
    end

    if greedy
      nil while consume.call
      while count >= min
        result = rest.call(position)
        return result if result

        position -= 1
        count -= 1
      end
      return nil
    end

    while count < min
      return nil unless consume.call
    end
    loop do
      result = rest.call(position)
      return result if result
      return nil unless consume.call
    end
  end
end

class String
  alias sub_with_string sub
  alias gsub_with_string gsub

  def sub(pattern, *rest, &block)
    return sub_with_string(pattern, *rest, &block) unless pattern.is_a?(Regexp)

    found = pattern.match(self)
    return dup unless found

    found.pre_match + (block ? block.call(found[0]) : rest[0]) + found.post_match
  end

  def gsub(pattern, *rest, &block)
    return gsub_with_string(pattern, *rest, &block) unless pattern.is_a?(Regexp)

    result = ''
    remaining = self
    while (found = pattern.match(remaining))
      result += found.pre_match + (block ? block.call(found[0]) : rest[0])
      remaining = found.post_match
      next unless found[0].empty?
      break if remaining.empty?

      result += remaining[0]
      remaining = remaining[1..-1]
    end
    result + remaining
  end

  def =~(pattern) = pattern.is_a?(Regexp) ? pattern =~ self : nil
  def match(pattern) = regexp_for(pattern).match(self)
  def match?(pattern) = regexp_for(pattern).match?(self)

  def scan(pattern)
    regexp = regexp_for(pattern)
    results = []
    remaining = self
    while (found = regexp.match(remaining))
      results << (found.captures.empty? ? found[0] : found.captures)
      remaining = found.post_match
      next unless found[0].empty?
      break if remaining.empty?

      remaining = remaining[1..-1]
    end
    results
  end

  private

  def regexp_for(pattern)
    pattern.is_a?(Regexp) ? pattern : Regexp.new(Regexp.escape(pattern))
  end
end

class Symbol
  def =~(pattern) = to_s =~ pattern
  def match?(pattern) = to_s.match?(pattern)
end
