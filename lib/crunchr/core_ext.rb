# = stuff for dealing with statistics
#
# monkey patches Hash, Array, ActiveRecord::Base and ActiveRecord::Relation
#

class Hash
  def delta(other)
    return nil unless other.is_a?(Hash)

    delta = {}

    self.keys.each do |key|
      next if !other.has_key? key
      if self[key].is_a?(Hash)
        delta[key] = self[key].delta(other[key])
      else
        delta[key] = (self[key] - other[key]) rescue nil
      end
    end

    delta
  end
end

class Array
  def mean
    (self.sum * 1.0) / self.count
  end

  def stddev
    Math.sqrt(self.collect{ |i| (i - self.mean) ** 2 }.sum) / Math.sqrt(self.count - 1)
  end

  def median
    center = (self.count + (self.count % 2)) / 2
    list = self.sort

    self.count % 2 == 0 ?
     [ list[center - 1], list[center] ].mean :
     list[center - 1]
  end

  def range
    list = self.sort
    list.last - list.first
  end

  def mode
    counts = {}
    self.collect { |i| counts[i] ||= 0; counts[i] += 1 }
    counts.key(counts.values.sort.last)
  end
end
