require 'crunchr/core_ext'
require 'bigdecimal'

# Crunch statistics with fun
#
# @author Harotg de Mik
#
module Crunchr
  def self.included(base)
    base.extend(ClassMethods)
  end

  def zero; self.class.zero; end
  def checked(val); self.class.checked(val); end

  def delta(other)
    return nil if other.respond_to?(:data) && !other.data.is_a?(Hash)
    return nil unless self.data.is_a?(Hash)

    delta      = self.class.new
    delta.data = self.data.dup.delta(other.data)

    # make it read-only
    delta.readonly! if delta.respond_to?(:readonly!)

    return delta
  end

  # Get the value from the data
  #
  #   # Given a data tree that looks like
  #   { number: 1
  #     collection: {
  #       depth: 2
  #     }
  #     list: [ 1, 2, 3 ]
  #   }
  #
  #   fetch("number")           # => 1
  #   fetch("collection/depth") # => 2
  #   fetch("n'existe pas")     # => nil
  #   fetch("collection")       # => { depth: 2 }
  #   fetch("list")             # => nil - NaN && !Hash
  #
  # When you supply a calculation to fetch, it will delegate to calculate
  #   fetch("number : collection") # => 0.5 (1 / 2)
  #
  def fetch(key)
    return calculate(key) if key =~ / [*\/:x+-] /

    key = key.split(/\//).collect(&:to_sym) if key =~ /\//
    value = nil

    # fetch directly
    if [String, Symbol].include?(key.class)
      if self.data.has_key?(key)
        value = self.data.fetch(key)
      else
        value = self.data.fetch(key.to_sym) rescue nil
      end

    else
      value = self.data
      key.each do |sub|
        value = value.fetch(sub) rescue nil
      end
    end

    if value.is_a?(Numeric) || value.is_a?(Hash)
      return value
    end

  rescue => ex
    if self.class.respond_to?(:logger) && !self.class.logger.nil?
      self.class.logger.error "Error in #{self.class}.fetch(#{key}) for #{data}"
    end
  end

  # given a string like 'keys - doors', returns the amount of spare keys
  #
  # You can group calculations by surrounding them with (), eg:
  #
  #   (doors - keys) / (inhabitants - keys)
  #
  # Pass in real numbers if you like
  #
  #   (doors + 2) / keys
  #
  # @note
  #   The result is *always* a float.
  #   If anything fails, 0.0 is returned.
  #
  # @param  String key     The calculation to perform
  # @return Float  result
  #
  def calculate(key)
    while key =~ /\(/ && key =~ /\)/
      key.gsub!(/\(([^\(\)]+)\)/) do |calculation|
        calculate(calculation.gsub(/[\(\)]/, ''))
      end
    end

    (left, op, right) = key.split(/\s/)

    left = (
      left =~ /[^\d.]/ ? self.fetch(left) : BigDecimal.new(left)
    ) || zero()

    right = (
      right =~ /[^\d.]/ ? self.fetch(right) : BigDecimal.new(right)
    ) || zero()

    op = op == ":" ? "/" : op
    op = op == "x" ? "*" : op

    # make sure at least 1 hand is a float
    left *= 1.0 if [left.class, right.class].include?(Fixnum)

    value = ( left.send(op, right) ) rescue zero()
    return checked(value)
  end

  module ClassMethods
    # pass in a list off data-objects with and get a nice table
    #   list = [ Object.data({ doors: 1, keys: 2}),
    #            Object.data({ doors: 1, keys: 3 },
    #            ...
    #          ]
    #
    #   table = Object.as_table(list, keys: %w[doors keys])
    #   # => [ [ 1, 2 ], [ 1, 3 ], [ 1, 4 ], [ 3, 8 ] ]
    #
    # Or use lists in lists
    #
    #   deep_list = [ list, list list ]
    #   table = Object.as_table(
    #     deep_list, keys: %[doors keys], list_operator: delta
    #   )
    #   # => [ [ 2, 6 ] ]  (difference of max and min for both doors and keys)
    #
    # == Usage with dates/times
    #
    # If you include Crunchr into something Active-Modely that has 'created_at'
    # as a (sane) attribute, you can supply a :date key, it will add a column
    # with the value of created_at into the table. If you do not supply
    # :date_fmt, it will call #to_date on the column
    #
    # @param [Array] list List (1d or 2d) of data objects
    # @param [Hash] opts Options
    # @option opts [Array] keys List of keys to fetch, may contain
    #     calculations, eg: ['doors', 'keys', 'doors / keys']
    # @option opts [Symbol] list_operator    With a 2d list, what operator to
    #      apply to each given list to determine the 1d value see #delta for
    #      more info
    # @option opts [String] date_fmt  Use as input to #strftime for the value
    #      in the date column
    # @option opts [String] str_fmt   Use as input to #sprintf for the value
    #      in **every** column. (Cannot be used together with :delta)
    # @option opts [Boolean] delta    After the first row, fill every other row
    #      with the difference to the previous row. (Cannot be used with
    #      :str_fmt)
    #
    def as_table(list, opts = {})
      keys = opts[:keys] || raise("Need keys")

      if opts[:delta] && opts[:str_fmt]
        raise ":delta and :str_fmt cannot be supplied together"
      end

      table = []

      list.each do |statistic|
        iteration_keys = keys.dup

        if statistic.is_a?(Array)
          (iteration_keys, statistic) = flatten(statistic, opts)
        end

        row = []

        iteration_keys.each do |key|
          value = zero()

          if key == :date
            value = opts[:date_fmt] ?
              statistic.created_at.strftime(opts[:date_fmt]) :
              statistic.created_at.to_date

          else
            value = statistic.fetch(key)

            if value.respond_to? :round
              value = case opts[:round]
                      when nil
                        value
                      when 0
                        value.round rescue value
                      else
                        value.round(opts[:round])
                      end
            end

            value = opts[:str_fmt] % value if opts[:str_fmt]

            value = value.to_f if value.is_a?(BigDecimal)
          end

          row << checked(value)
        end

        if opts[:delta] && table.any?
          new_row = []
          row.each_with_index do |value, idx|
            next unless value.kind_of?(Numeric)
            new_row[idx] = checked(row[idx] - @prev[idx])
          end

          @prev = row.dup
          row = new_row
        else
          @prev = row
        end

        table << row
      end

      return table
    end

    # flatten an array of rows by applying an operator vertically on each
    # column and accepting the result as a single row
    #
    # @param [Array] array List of lists
    # @param [Hash] opts Options
    # @option opts [Symbol] list_operator  What operator to apply to the array
    #   to get a single value, defaults to :mean, should be any of
    #      - :mean
    #      - :stddev
    #      - :median
    #      - :range
    #      - :mode
    #      - :sum
    #      - :min
    #      - :max
    #      - :delta (takes the difference of max and min)
    #
    def flatten(array, opts)
      keys = opts[:keys].dup

      # this must be an interval period : find the mean, sum, max, whatever
      opts[:list_operator] ||= :mean

      collection = self.new( :data => {} )

      keys.each_with_index do |key, idx|
        if key == :date
          collection.created_at = array.first.created_at
          next
        end

        collection_key = key.to_s.gsub(/[\s*\/:x+-]+/, '_')
        keys[idx] = collection_key if collection_key != key

        array.each do |item|
          collection.data[collection_key] ||= []
          collection.data[collection_key] << (item.fetch(key) || 0)
        end

        # turn the collection into a single value
        value = if opts[:list_operator] == :delta
          collection.data[collection_key].max -
          collection.data[collection_key].min

        else
           collection.data[collection_key].send(opts[:list_operator])

        end

        collection.data[collection_key] = value
      end

      collection
      collection.readonly! if collection.respond_to?(:readonly!)

      return [keys, collection]
    end

    # Return a BigDecimal zero value
    def zero
      BigDecimal.new("0.0")
    end

    # Make sure the value is zero if it is NaN, infinite, or nil
    # Turn the value into a float if it is a BigDecimal
    #
    # @param value  The value to check
    # @return [Float, Integer] the improved value
    def checked(value)
      value = zero() if value.respond_to?(:nan?) && value.nan?
      value = zero() if value.respond_to?(:infinity?) && value.infinity?
      value = zero() if value.nil?
      value = value.to_f if value.is_a? BigDecimal

      value
    end
  end
end
