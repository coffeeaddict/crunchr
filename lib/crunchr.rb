require 'crunchr/core_ext'

# Crunch statistics with fun
#
# @author Harotg de Mik
#
module Crunchr
  def delta(other)
    return nil unless other.respond_to?(:data) && !other.data.is_a?(Hash)
    return nil unless self.data.is_a?(Hash)

    delta = self.class.new( :data => self.data.delta(other.data) )

    # make it read-only
    delta.readonly! if delta.respond_to?(:readonly!)

    return delta
  end

  def fetch(key)
    return calculate(key) if key =~ / [*\/:x+-] /

    key = key.split(/\//).collect(&:to_sym) if key =~ /\//
    value = nil

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

    return value

  rescue => ex
    if self.class.respond_to?(:logger) && !self.class.logger.nil?
      self.class.logger.error "Error in Statistic.fetch(#{key}) for #{data}"
    end
  end

  # given a string like 'keys - doors', returns the amount of spare keys
  #
  def calculate(key)
    (left, op, right) = key.split(/\s/)

    left  = self.fetch(left) || zero()
    right = self.fetch(right) || zero()
    op    = op == ":" ? "/" : op
    op    = op == "x" ? "*" : op

    left *= 1.0 if op == "/"

    value = ( left.send(op, right) ) rescue zero()
    return checked(value)
  end

  def self.as_table(list, opts = {})
    keys = opts[:keys] || raise("Need keys")

    table = []

    list.each do |statistic|
      round_keys = keys.dup
      if statistic.is_a?(Array)
        # this must be an interval period : find the mean, sum, max, whatever
        opts[:list_operator] ||= :mean

        collection = Statistic.new( :data => {} )
        round_keys.each_with_index do |key, idx|
          if key == :date
            collection.created_at = statistic.first.created_at
            next
          end

          collection_key = key.to_s.gsub(/[\s*\/:x+-]+/, '_')
          round_keys[idx] = collection_key if collection_key != key

          statistic.each do |item|
            collection.data[collection_key] ||= []
            collection.data[collection_key] << (item.fetch(key) || 0)
          end

          # turn the collection into a single value
          if opts[:list_operator] == :delta
            value = ( collection.data[collection_key].max -
                      collection.data[collection_key].min
                    )

          else
            value = collection.data[collection_key].send(opts[:list_operator])

          end

          collection.data[collection_key] = value
        end

        statistic = collection
        statistic.readonly!
      end

      row = []

      round_keys.each do |key|
        value = zero()

        if key == :date
          value = opts[:date_fmt] ?
            statistic.created_at.strftime(opts[:date_fmt]) :
            statistic.created_at.to_date

        else
          value = statistic.fetch(key)
        end

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

        row << checked(value)
      end

      if opts[:delta] && table.any?
        prev = table.last
        row.each_with_index do |value, idx|
          next unless value.kind_of?(Numeric)
          row[idx] = checked(row[idx] - prev[idx])
        end
      end

      table << row
    end

    return table
  end

  def self.zero
    BigDecimal.new("0.0")
  end
  def zero; self.class.zero; end

  def self.checked(value)
    value = zero() if value.respond_to?(:nan?) && value.nan?
    value = zero() if value.respond_to?(:infinity?) && value.infinity?
    value = zero() if value.nil?
    value = value.to_f if value.is_a? BigDecimal

    value
  end
  def checked(value); self.class.checked(value); end
end
