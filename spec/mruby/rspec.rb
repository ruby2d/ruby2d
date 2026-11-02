# MiniSpec

# The subset of RSpec that `spec/` uses, in plain Ruby, so the specs can run on
# mruby, where RSpec itself can't. `rake spec:native` and `rake spec:web` compile
# this file, `regexp.rb`, `stdlib.rb`, and the spec files into one app.
#
# Two metadata keys skip an example, each taking the reason as its value. RSpec
# ignores them both:
#
#   it 'reads the source', skip_mruby: 'no lib/ at runtime' do  # native and web
#   it 'saves a file', skip_web: 'screenshot is a no-op' do     # web only
#
# A matcher this file doesn't define raises `NoMethodError`, which fails the
# example, so a spec can't pass by reaching for something nothing here checks.
module MiniSpec
  # Exception rather than StandardError, as in RSpec, so a `rescue` in the code
  # under test can't swallow a failed expectation.
  class Failure < Exception; end
  class Skip < Exception; end

  EXAMPLES = []
  SHARED = {}
  CONFIG_BEFORE = []
  STUBS = []
  EXPECTED_CALLS = []

  @call_count = 0
  @last_ordered_call = -1

  def self.short(value)
    text = value.inspect
    text.length > 240 ? "#{text[0, 240]}..." : text
  end

  def self.value_matches?(expected, actual)
    return expected.matches?(actual) if expected.respond_to?(:matches?)

    expected === actual || actual == expected
  end

  def self.same_items?(actual, expected)
    actual = actual.to_a
    return false unless actual.length == expected.length

    rest = expected.dup
    actual.each do |item|
      index = rest.index { |candidate| value_matches?(candidate, item) }
      return false unless index

      rest.delete_at(index)
    end
    true
  end

  # Stubs ######################################################################

  Call = Struct.new(:order, :args)

  def self.next_call_order
    @call_count += 1
  end

  # A stubbed method. Records every call and answers the way rspec-mocks does:
  # from the first matching `expect` still short of its count, otherwise from
  # the latest matching `allow`. An `expect` with no answer of its own borrows the
  # `allow`'s, and a call past a bare `expect` goes to the `allow` uncounted, while
  # one with an explicit count takes the call and then fails on it.
  class Stub
    attr_reader :target, :name, :calls, :allowed, :expected

    def self.for(target, name)
      found = find(target, name)
      return found if found

      stub = new(target, name)
      STUBS << stub
      stub
    end

    def self.find(target, name)
      STUBS.find { |stub| stub.target.equal?(target) && stub.name == name }
    end

    def initialize(target, name)
      @target = target
      @name = name
      @calls = []
      @allowed = []
      @expected = []
      @original = target.respond_to?(name, true) ? target.method(name) : nil
      @own_method = target.singleton_methods(false).include?(name)
      stub = self
      target.define_singleton_method(name) do |*args, **kwargs, &block|
        stub.dispatch(args, kwargs, block)
      end
    end

    def dispatch(args, kwargs, block)
      all_args = kwargs.empty? ? args : args + [kwargs]
      call = Call.new(MiniSpec.next_call_order, all_args)
      @calls << call
      allowed = @allowed.reverse.find { |response| response.args_match?(all_args) }
      expected = expectation_for(all_args)
      unless allowed || expected
        raise Failure, "#{@name} received unexpected args #{MiniSpec.short(all_args)}"
      end

      if allowed && (expected.nil? || expected.at_limit?)
        expected.received << call if expected && expected.explicit_count?
        allowed.answer(self, args, kwargs, block)
      else
        expected.received << call
        expected.answer(self, args, kwargs, block, allowed)
      end
    end

    def call_original(args, kwargs, block)
      raise "#{@name} has no original to call" unless @original

      kwargs.empty? ? @original.call(*args, &block) : @original.call(*args, **kwargs, &block)
    end

    def restore
      if @own_method
        stub = self
        @target.define_singleton_method(@name) do |*args, **kwargs, &block|
          stub.call_original(args, kwargs, block)
        end
      else
        @target.singleton_class.send(:remove_method, @name)
      end
    end

    private

    def expectation_for(args)
      matching = @expected.select { |response| response.args_match?(args) }
      matching.find { |response| !response.at_limit? } || matching.first
    end
  end

  # The chain after `receive(:name)`, and after `have_received(:name)`. With no
  # count, both mean exactly once.
  module CallCounts
    def once = exactly(1)
    def twice = exactly(2)
    def never = exactly(0)
    def times = self

    def exactly(count)
      @expected_count = count
      self
    end

    def expected_count = @expected_count || 1
    def explicit_count? = !@expected_count.nil?

    def ordered
      @ordered = true
      self
    end

    def ordered? = @ordered
  end

  class Receive
    include CallCounts

    attr_reader :name, :received
    attr_writer :implementation

    def initialize(name, implementation = nil)
      @name = name
      @implementation = implementation
      @next_value = 0
      @received = []
    end

    # `and_return(1, 2)` expects a call for each value.
    def expected_count = @expected_count || [1, @values ? @values.length : 0].max
    def at_limit? = expected_count > 0 && @received.length >= expected_count

    def with(*args, **kwargs, &block)
      @expected_args = kwargs.empty? ? args : args + [kwargs]
      @implementation = block if block
      self
    end

    def and_return(*values)
      @values = values
      self
    end

    def and_raise(*error)
      @error = error
      self
    end

    def and_call_original
      @call_original = true
      self
    end

    def args_match?(args)
      return true if @expected_args.nil?
      return args.empty? if @expected_args.length == 1 && @expected_args[0].is_a?(NoArgs)
      return false unless @expected_args.length == args.length

      @expected_args.each_with_index.all? do |expected, i|
        MiniSpec.value_matches?(expected, args[i])
      end
    end

    def answer(stub, args, kwargs, block, fallback = nil)
      raise(*@error) if @error
      return stub.call_original(args, kwargs, block) if @call_original
      return call_implementation(args, kwargs, block) if @implementation
      return next_value if @values

      fallback ? fallback.answer(stub, args, kwargs, block) : nil
    end

    private

    # Each value in turn, then the last one for good.
    def next_value
      value = @values[@next_value < @values.length ? @next_value : -1]
      @next_value += 1
      value
    end

    def call_implementation(args, kwargs, block)
      return @implementation.call(*args, &block) if kwargs.empty?

      @implementation.call(*args, **kwargs, &block)
    end
  end

  class NoArgs; end

  # `allow(target)`
  class AllowTarget
    def initialize(target)
      @target = target
    end

    def to(response, &block)
      response.implementation = block if block
      Stub.for(@target, response.name).allowed << response
      response
    end
  end

  def self.expect_call(target, response)
    Stub.for(target, response.name).expected << response
    EXPECTED_CALLS << response
    response
  end

  # All of these calls have to follow every earlier `.ordered` one. Expectations
  # check here when the example ends and `have_received` as it's reached, so an
  # example has to use one or the other for this to mean anything.
  def self.check_order(calls)
    return false unless calls.first.order > @last_ordered_call

    @last_ordered_call = calls.last.order
    true
  end

  def self.verify_expected_calls
    EXPECTED_CALLS.each do |response|
      calls = response.received
      unless calls.length == response.expected_count
        raise Failure, "expected #{response.name} #{response.expected_count} times, got #{calls.length}"
      end
      if response.ordered? && !check_order(calls)
        raise Failure, "expected #{response.name} to be received in order"
      end
    end
  end

  def self.reset_example_state
    STUBS.reverse.each(&:restore)
    STUBS.clear
    EXPECTED_CALLS.clear
    @last_ordered_call = -1
  end

  # Matchers ###################################################################

  # A matcher answers `matches?`. One that takes several values also answers
  # `does_not_match?`, since `not_to` then means none of them, not "not all".
  class Matcher
    attr_reader :message

    def and(other) = Both.new(self, other)
    def negated_message = "not: #{message}"
  end

  class Both < Matcher
    def initialize(first, second)
      @first = first
      @second = second
    end

    def matches?(actual)
      matched = @first.matches?(actual) && @second.matches?(actual)
      @message = "#{@first.message} and #{@second.message}"
      matched
    end
  end

  class Predicate < Matcher
    def initialize(description, &block)
      @description = description
      @block = block
    end

    def matches?(actual)
      @message = "expected #{MiniSpec.short(actual)} #{@description}"
      @block.call(actual)
    end
  end

  # `be(value)` is identity; `be > 1` and the like compare.
  class Be < Matcher
    def initialize(*expected)
      @expected = expected
    end

    def matches?(actual)
      if @expected.empty?
        @message = "expected #{MiniSpec.short(actual)} to be truthy"
        return !!actual
      end

      @message = "expected #{MiniSpec.short(actual)} to be #{MiniSpec.short(@expected[0])}"
      actual.equal?(@expected[0])
    end

    %i[> >= < <=].each do |operator|
      define_method(operator) do |other|
        Predicate.new("to be #{operator} #{MiniSpec.short(other)}") { |x| x.send(operator, other) }
      end
    end
  end

  class Within < Matcher
    def initialize(delta)
      @delta = delta
    end

    def of(value)
      @value = value
      self
    end

    def matches?(actual)
      @message = "expected #{MiniSpec.short(actual)} within #{@delta} of #{@value}"
      actual.respond_to?(:-) && (actual - @value).abs <= @delta
    end
  end

  class Between < Matcher
    def initialize(low, high)
      @low = low
      @high = high
    end

    def exclusive
      @exclusive = true
      self
    end

    def matches?(actual)
      @message = "expected #{MiniSpec.short(actual)} between #{@low} and #{@high}"
      return actual > @low && actual < @high if @exclusive

      actual >= @low && actual <= @high
    end
  end

  class RaiseError < Matcher
    def initialize(error_class = nil, expected_message = nil, &block)
      if error_class.is_a?(String) || error_class.is_a?(Regexp)
        expected_message = error_class
        error_class = nil
      end
      @error_class = error_class
      @expected_message = expected_message
      @block = block
    end

    def matches?(callable)
      @raised = nil
      begin
        callable.call
      rescue Failure, Skip => e
        raise e
      rescue Exception => e
        @raised = e
      end
      @message = "expected #{description}, got #{raised_description || 'nothing'}"
      return false unless @raised
      return false if @error_class && !@raised.is_a?(@error_class)
      return false unless message_matches?(@raised.message.to_s)

      @block.call(@raised) if @block
      true
    end

    def negated_message = "expected no error, got #{raised_description}"

    private

    def description
      expected = @expected_message ? " #{MiniSpec.short(@expected_message)}" : ''
      "#{@error_class || 'an error'}#{expected}"
    end

    def raised_description
      "#{@raised.class}: #{MiniSpec.short(@raised.message)}" if @raised
    end

    def message_matches?(text)
      case @expected_message
      when nil then true
      when Regexp then @expected_message.match?(text)
      else MiniSpec.value_matches?(@expected_message, text)
      end
    end
  end

  class Change < Matcher
    def initialize(object = nil, method_name = nil, &block)
      @read = block || -> { object.send(method_name) }
    end

    def by(amount)
      @by = amount
      self
    end

    def from(value)
      @from = value
      @check_from = true
      self
    end

    def to(value)
      @to = value
      @check_to = true
      self
    end

    def matches?(callable)
      before = @read.call
      callable.call
      after = @read.call
      @message = "expected a change, got #{MiniSpec.short(before)} to #{MiniSpec.short(after)}"
      return false if @check_from && before != @from
      return false if @check_to && after != @to
      return after - before == @by unless @by.nil?

      before != after
    end
  end

  # Stands in for `$stderr` while `output` captures it. `Ruby2D.warn` and
  # `Ruby2D.info` are all that write there, and they only use `puts`.
  class Capture
    attr_reader :text

    def initialize
      @text = ''
    end

    def puts(*lines)
      lines.each { |line| @text += "#{line}\n" }
      nil
    end
  end

  # `output(...).to_stderr`
  class Output < Matcher
    def initialize(expected = nil)
      @expected = expected
    end

    def to_stderr = self

    def matches?(callable)
      capture = Capture.new
      saved = $stderr
      begin
        $stderr = capture
        callable.call
      ensure
        $stderr = saved
      end
      got = capture.text
      @message = "expected stderr #{MiniSpec.short(@expected)}, got #{MiniSpec.short(got)}"
      case @expected
      when nil then !got.empty?
      when Regexp then @expected.match?(got)
      else MiniSpec.value_matches?(@expected, got)
      end
    end
  end

  class HaveReceived < Matcher
    include CallCounts

    def initialize(name)
      @name = name
      @response = Receive.new(name)
    end

    def with(*args, **kwargs)
      @response.with(*args, **kwargs)
      self
    end

    def matches?(target)
      stub = Stub.find(target, @name)
      @message = "expected #{@name} to have been received"
      return false unless stub

      calls = matching_calls(stub)
      @message = "expected #{@name} #{expected_count} times, got #{calls.length} matching " \
                 "calls of #{stub.calls.length}"
      return false unless calls.length == expected_count

      !ordered? || MiniSpec.check_order(calls)
    end

    def does_not_match?(target)
      stub = Stub.find(target, @name)
      @message = "expected #{@name} to be stubbed, and not to have been received"
      !stub.nil? && matching_calls(stub).empty?
    end

    def negated_message = @message

    private

    def matching_calls(stub)
      stub.calls.select { |call| @response.args_match?(call.args) }
    end
  end

  class RespondTo < Matcher
    def initialize(*names)
      @names = names
    end

    def matches?(actual)
      @message = "expected #{MiniSpec.short(actual)} to respond to #{@names}"
      @names.all? { |name| actual.respond_to?(name) }
    end

    def does_not_match?(actual)
      @message = "expected #{MiniSpec.short(actual)} not to respond to #{@names}"
      @names.none? { |name| actual.respond_to?(name) }
    end

    def negated_message = @message
  end

  class Include < Matcher
    def initialize(*expected)
      @expected = expected
    end

    def matches?(actual)
      @message = "expected #{MiniSpec.short(actual)} to include #{MiniSpec.short(@expected)}"
      @expected.all? { |item| included?(actual, item) }
    end

    def does_not_match?(actual)
      @message = "expected #{MiniSpec.short(actual)} not to include #{MiniSpec.short(@expected)}"
      items = @expected.flat_map do |item|
        item.is_a?(Hash) ? item.map { |key, value| { key => value } } : [item]
      end
      items.none? { |item| included?(actual, item) }
    end

    def negated_message = @message

    private

    def included?(actual, item)
      if actual.is_a?(Hash)
        return actual.keys.any? { |key| MiniSpec.value_matches?(item, key) } unless item.is_a?(Hash)

        item.all? { |key, value| actual.key?(key) && MiniSpec.value_matches?(value, actual[key]) }
      elsif actual.is_a?(String)
        item.is_a?(Regexp) ? item.match?(actual) : actual.include?(item)
      else
        actual.any? { |element| MiniSpec.value_matches?(item, element) }
      end
    end
  end

  # What an example can call: `expect`, the matchers, and the stubbing helpers.
  module Dsl
    def expect(*value, &block)
      Expectation.new(value.empty? ? block : value[0])
    end

    def eq(value) = Predicate.new("to eq #{MiniSpec.short(value)}") { |x| x == value }
    def equal(value) = Predicate.new("to be #{MiniSpec.short(value)}") { |x| x.equal?(value) }
    def be(*expected) = Be.new(*expected)
    def be_nil = Predicate.new('to be nil') { |x| x.nil? }
    def be_falsey = Predicate.new('to be falsey') { |x| !x }
    def be_a(klass) = Predicate.new("to be a #{klass}") { |x| x.is_a?(klass) }
    def be_an(klass) = be_a(klass)
    def kind_of(klass) = be_a(klass)
    def be_within(delta) = Within.new(delta)
    def be_between(low, high) = Between.new(low, high)
    def be_empty = Predicate.new('to be empty') { |x| x.empty? }
    def be_frozen = Predicate.new('to be frozen') { |x| x.frozen? }
    def include(*expected) = Include.new(*expected)

    def match(pattern)
      Predicate.new("to match #{MiniSpec.short(pattern)}") do |x|
        pattern.is_a?(Regexp) ? pattern.match?(x.to_s) : MiniSpec.value_matches?(pattern, x)
      end
    end

    def match_array(items)
      Predicate.new("to match #{MiniSpec.short(items)}") { |x| MiniSpec.same_items?(x, items) }
    end

    def contain_exactly(*items) = match_array(items)

    def start_with(*prefixes)
      Predicate.new("to start with #{MiniSpec.short(prefixes)}") do |x|
        next x[0, prefixes.length] == prefixes if x.is_a?(Array)

        prefixes.length == 1 && x.start_with?(prefixes[0])
      end
    end

    def end_with(*suffixes)
      Predicate.new("to end with #{MiniSpec.short(suffixes)}") do |x|
        next x[-suffixes.length, suffixes.length] == suffixes if x.is_a?(Array)

        suffixes.length == 1 && x.end_with?(suffixes[0])
      end
    end

    def respond_to(*names) = RespondTo.new(*names)

    def satisfy(_description = nil, &block) = Predicate.new('to satisfy the block', &block)
    def all(matcher) = Predicate.new('all to match') { |x| x.all? { |y| matcher.matches?(y) } }

    def have_attributes(expected)
      Predicate.new("to have attributes #{MiniSpec.short(expected)}") do |x|
        expected.all? { |name, value| MiniSpec.value_matches?(value, x.send(name)) }
      end
    end

    def raise_error(*args, &block) = RaiseError.new(*args, &block)
    def change(*args, &block) = Change.new(*args, &block)
    def output(expected = nil) = Output.new(expected)
    def anything = Predicate.new('to be anything') { |_| true }
    def no_args = NoArgs.new
    def allow(target) = AllowTarget.new(target)
    def receive(name, &block) = Receive.new(name, block)
    def have_received(name) = HaveReceived.new(name)
    def skip(reason = '') = raise(Skip, reason)
    def described_class = self.class.described_class
  end

  class Expectation
    def initialize(actual)
      @actual = actual
    end

    def to(matcher, failure_message = nil, &block)
      if matcher.is_a?(Receive)
        matcher.implementation = block if block
        return MiniSpec.expect_call(@actual, matcher)
      end
      # Whatever the block asserts would otherwise never run.
      raise ArgumentError, '`to` only takes a block with `receive`' if block
      raise Failure, failure_message || matcher.message unless matcher.matches?(@actual)

      true
    end

    def not_to(matcher, failure_message = nil)
      return MiniSpec.expect_call(@actual, matcher.never) if matcher.is_a?(Receive)

      absent = if matcher.respond_to?(:does_not_match?)
                 matcher.does_not_match?(@actual)
               else
                 !matcher.matches?(@actual)
               end
      raise Failure, failure_message || matcher.negated_message unless absent

      true
    end

    def to_not(matcher, failure_message = nil) = not_to(matcher, failure_message)
  end

  # Groups #####################################################################

  # `describe` and `context` subclass Group, so `let` and helper methods inherit
  # the way they do in RSpec, and each example runs in a fresh instance.
  class Group
    include Dsl

    class << self
      attr_reader :parent_group, :descriptions, :before_hooks, :after_hooks, :around_hooks

      def set_up_group(parent, descriptions)
        @parent_group = parent
        @descriptions = descriptions
        @before_hooks = []
        @after_hooks = []
        @around_hooks = []
      end

      # This group and the ones it's nested in, outermost first.
      def lineage
        groups = []
        group = self
        while group && group.descriptions
          groups.unshift(group)
          group = group.parent_group
        end
        groups
      end

      def full_description
        lineage.map { |group| group.descriptions.map(&:to_s).join(' ') }.join(' ')
      end

      def described_class
        lineage.reverse.each do |group|
          found = group.descriptions.find { |item| item.is_a?(Module) }
          return found if found
        end
        nil
      end

      def describe(*descriptions, **_metadata, &block)
        group = Class.new(self)
        group.set_up_group(self, descriptions)
        group.class_exec(&block) if block
        group
      end

      def context(*descriptions, **metadata, &block)
        describe(*descriptions, **metadata, &block)
      end

      def it(description = nil, **metadata, &block)
        EXAMPLES << Example.new(self, description.to_s, block, metadata)
      end

      def specify(description = nil, **metadata, &block)
        it(description, **metadata, &block)
      end

      def before(_scope = :each, &block) = @before_hooks << block
      def after(_scope = :each, &block) = @after_hooks << block
      def around(_scope = :each, &block) = @around_hooks << block

      def let(name, &block)
        define_method(name) do
          @memoized ||= {}
          @memoized[name] = instance_exec(&block) unless @memoized.key?(name)
          @memoized[name]
        end
      end

      def let!(name, &block)
        let(name, &block)
        before { send(name) }
      end

      def subject(name = nil, &block)
        let(:subject, &block)
        let(name) { subject } if name
      end

      def shared_examples(name, &block) = SHARED[name] = block
      def shared_context(name, &block) = SHARED[name] = block

      def include_examples(name, *args, **kwargs, &block)
        shared = SHARED[name]
        raise "no shared examples named #{name}" unless shared

        kwargs.empty? ? class_exec(*args, &shared) : class_exec(*args, **kwargs, &shared)
        class_exec(&block) if block
      end

      def include_context(name, *args, **kwargs, &block)
        include_examples(name, *args, **kwargs, &block)
      end
    end

    attr_accessor :example_body

    def subject
      @subject ||= self.class.described_class.new
    end
  end

  # What `around` hooks call `run` on.
  class ExampleHandle
    def initialize(callable)
      @callable = callable
    end

    def run = @callable.call
  end

  Example = Struct.new(:group, :description, :body, :metadata) do
    def full_description = "#{group.full_description} #{description}"

    def skip_reason
      metadata[:skip_mruby] || (metadata[:skip_web] if Ruby2D.web?)
    end

    def run
      instance = group.new
      lineage = group.lineage
      run_with_hooks = -> { run_body(instance, lineage) }
      around_hooks = lineage.flat_map(&:around_hooks)
      around_hooks.reverse.inject(run_with_hooks) { |inner, hook|
        -> { instance.instance_exec(ExampleHandle.new(inner), &hook) }
      }.call
    end

    private

    def run_body(instance, lineage)
      begin
        CONFIG_BEFORE.each { |hook| instance.instance_exec(&hook) }
        lineage.each { |g| g.before_hooks.each { |hook| instance.instance_exec(&hook) } }
        instance.instance_exec(&body)
      ensure
        lineage.reverse.each do |g|
          g.after_hooks.reverse.each { |hook| instance.instance_exec(&hook) }
        end
      end
      MiniSpec.verify_expected_calls
    end
  end

  # Running ####################################################################

  class Configuration
    def before(_scope = :each, &block) = CONFIG_BEFORE << block
  end

  # Returns :passed, :skipped, or the text of the failure.
  def self.outcome_of(example)
    return :skipped if example.skip_reason

    example.run
    :passed
  rescue Skip
    :skipped
  rescue Failure => e
    e.message
  rescue Exception => e
    trace = e.backtrace ? e.backtrace.first(4).join("\n") : ''
    "#{e.class}: #{e.message}\n#{trace}"
  ensure
    reset_example_state
  end

  def self.report(failures, skipped)
    unless failures.empty?
      puts "\nFailures:\n\n"
      failures.each_with_index do |(example, text), i|
        puts "  #{i + 1}) #{example.full_description}"
        text.split("\n").each { |line| puts "     #{line}" }
        puts ''
      end
    end
    count = EXAMPLES.length
    puts "#{count} example#{'s' unless count == 1}, " \
         "#{failures.length} failure#{'s' unless failures.length == 1}, #{skipped} skipped"
  end

  # Announces each example before running it: if one takes the process down, the
  # last line says which, and the Rake task reports it.
  def self.run
    failures = []
    skipped = 0
    EXAMPLES.each do |example|
      puts ">> #{example.full_description}"
      $stdout.flush
      case outcome = outcome_of(example)
      when :passed then nil
      when :skipped then skipped += 1
      else failures << [example, outcome]
      end
    end
    report(failures, skipped)
    $stdout.flush
    # There's no process to give a status to on the web, where the Rake task
    # reads the summary instead.
    exit(failures.empty? ? 0 : 1) unless Ruby2D.web?
  end
end

module RSpec
  def self.describe(*descriptions, **metadata, &block)
    MiniSpec::Group.describe(*descriptions, **metadata, &block)
  end

  def self.configure = yield(MiniSpec::Configuration.new)
  def self.shared_context(name, &block) = MiniSpec::SHARED[name] = block
end

def shared_examples(name, &block) = MiniSpec::SHARED[name] = block
