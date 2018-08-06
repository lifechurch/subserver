# frozen_string_literal: true
module Subserver
  # Middleware is code configured to run before/after
  # a message is processed.  It is patterned after Rack
  # middleware. 
  #
  # To modify middleware for the server, just call
  # with another block:
  #
  # Subserver.configure do |config|
  #   config.middleware do |chain|
  #     chain.add MyServerHook
  #     chain.remove ActiveRecord
  #   end
  # end
  #
  # To insert immediately preceding another entry:
  #
  # Subserver.configure do |config|
  #   config.middleware do |chain|
  #     chain.insert_before ActiveRecord, MyServerHook
  #   end
  # end
  #
  # To insert immediately after another entry:
  #
  # Subserver.configure do |config|
  #   config.middleware do |chain|
  #     chain.insert_after ActiveRecord, MyServerHook
  #   end
  # end
  #
  # This is an example of a minimal server middleware:
  #
  # class MyServerHook
  #   def call(subscriber_class, message)
  #     puts "Before work"
  #     yield
  #     puts "After work"
  #   end
  # end
  #
  #
  module Middleware
    class Chain
      include Enumerable
      attr_reader :entries

      def initialize_copy(copy)
        copy.instance_variable_set(:@entries, entries.dup)
      end

      def each(&block)
        entries.each(&block)
      end

      def initialize
        @entries = []
        yield self if block_given?
      end

      def remove(klass)
        entries.delete_if { |entry| entry.klass == klass }
      end

      def add(klass, *args)
        remove(klass) if exists?(klass)
        entries << Entry.new(klass, *args)
      end

      def prepend(klass, *args)
        remove(klass) if exists?(klass)
        entries.insert(0, Entry.new(klass, *args))
      end

      def insert_before(oldklass, newklass, *args)
        i = entries.index { |entry| entry.klass == newklass }
        new_entry = i.nil? ? Entry.new(newklass, *args) : entries.delete_at(i)
        i = entries.index { |entry| entry.klass == oldklass } || 0
        entries.insert(i, new_entry)
      end

      def insert_after(oldklass, newklass, *args)
        i = entries.index { |entry| entry.klass == newklass }
        new_entry = i.nil? ? Entry.new(newklass, *args) : entries.delete_at(i)
        i = entries.index { |entry| entry.klass == oldklass } || entries.count - 1
        entries.insert(i+1, new_entry)
      end

      def exists?(klass)
        any? { |entry| entry.klass == klass }
      end

      def retrieve
        map(&:make_new)
      end

      def clear
        entries.clear
      end

      def invoke(*args)
        chain = retrieve.dup
        traverse_chain = lambda do
          if chain.empty?
            yield
          else
            chain.shift.call(*args, &traverse_chain)
          end
        end
        traverse_chain.call
      end
    end

    class Entry
      attr_reader :klass

      def initialize(klass, *args)
        @klass = klass
        @args  = args
      end

      def make_new
        @klass.new(*@args)
      end
    end
  end
end