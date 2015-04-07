require 'rubygems'
require 'logger'
require 'stringio'
require 'bundler'
Bundler.require(:default, :development)

ActiveRecord::Base.logger = Logger.new(StringIO.new)
puts "Testing with ActiveRecord #{ActiveRecord::VERSION::STRING}"

require File.expand_path('../../lib/acts_as_revisionable', __FILE__)
require 'sqlite3'

module ActsAsRevisionable
  module Test
    def self.create_database
      ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")
    end

    def self.delete_database
      ActiveRecord::Base.connection.drop_table(ActsAsRevisionable::RevisionRecord.table_name)
      ActiveRecord::Base.connection.disconnect!
    end
  end
end

# Tests method chains that take arguments.
# Can create something similar to a test double, or allows the first method call
# to start from an existing object.
class ChainedMock < BasicObject
  # To intercept normal Object methods, we need to inherit from BasicObject.

  class << self
    # Works similarly to .new, but also verifies the chain was fulfilled if the
    # block exits successfully.
    def with_fulfillment_check(*args)
      chain = new(*args)
      yield chain
      # This check is only done if no error is raised in the yield
      chain.__fulfilled__ == true or raise "#{chain.__send__(:self_display)} : chain wasn't fulfilled"
    end
  end

  # name_or_receiver can be:
  # - String or symbol: this will be a standalone mock
  # - Anything else: the first method will be stubbed on the receiver, the remaining will be on the mock.
  #   Do not use this style if call_order only contains one method.
  #
  # call_order: ArrayOf: [method_symbol, args] OR method_symbol
  # Note that if there are no args, you don't have wrap the method_symbol in an array.
  # E.g.
  #   ChainedMock.new(:mockthing, [[:order, 'ordcol desc'], [:where, a: 1, b: 2], [:where, c: 2, d: 3], :first], rec)
  def initialize(name_or_receiver, call_order, return_val)
    @name_or_receiver = name_or_receiver
    @call_order = call_order
    setup_mock
    @ret_val = return_val
    @remaining_calls = call_order.dup
    @fulfilled = false
  end

  # true if all methods in the chain were called.
  # The odd naming is to avoid clashes with the methods in the chain.
  def __fulfilled__; @fulfilled; end

  private
  # NOTE: do not call self.class (unless you've defined the public method #class),
  # otherwise method_missing will keep calling itself and overflow the stack.
  def class_name
    "ChainedMock"
  end
  # BasicObject doesn't have this method
  def raise(*args)
    # All external constant access must be scoped from top-level.
    ::Kernel.raise(*args)
  end
  def self_display
    "#{class_name} #{@name_or_receiver.inspect}"
  end
  # @call_order may be modified
  def setup_mock
    case @name_or_receiver
    when ::String, ::Symbol
      # nothing
    else
      expected_name, *expected_args = @call_order.shift
      @name_or_receiver.stub(expected_name).with(*expected_args).and_return self
    end
  end

  def method_missing(name, *args)
    raise "#{self_display} - can't call #{name.inspect} (call chain exhausted)"  if @remaining_calls.empty?

    expected_name, *expected_args = @remaining_calls.shift
    if name == expected_name and args == expected_args
      if @remaining_calls.any?
        self
      else
        @fulfilled = true
        @ret_val
      end
    else
      @remaining_calls.clear
      raise (<<-ERRMSG)
#{self_display} received unexpected call.
Expected: #{expected_name}(#{expected_args.map(&:inspect).join(', ')})
Received: #{name}(#{args.map(&:inspect).join(', ')})
      ERRMSG
    end
  end
end
