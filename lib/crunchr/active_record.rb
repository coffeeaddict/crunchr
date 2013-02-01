# = stuff for dealing with statistics
#
# monkey patches Hash, Array, ActiveRecord::Base and ActiveRecord::Relation
#

class Array
  # return an array of arrays where each inner array represents a period of
  # time
  #
  # == Synopsis
  #   timed_interval(:week, 2)   # two week periods
  #   timed_interval(:month, 6)  # half year periods
  #   timed_interval(:day, 1)    # per day
  #
  # == Prerequisites
  # The items in the list must respond_to interval_time and it must return
  # something that responds to < or >
  #
  def timed_interval(length, amount=1)
    list = self.sort_by(&:created_at)
    current = list.first.interval_time(length)


    records = []
    period  = []

    list.each do |record|
      if record.interval_time(length) > (current + (amount - 1))
        records << period
        period = []
        current = record.interval_time(length)
      end

      period << record
    end

    records
  end
end

class ActiveRecord::Base
  def interval_time(length)
    self.created_at.strftime(interval_fmt(length)).to_i
  end

  def interval_fmt(length)
    case length
    when :hour
      "%Y%j%H"
    when :day
      "%Y%j"
    when :week
      "%Y%W"
    when :month
      "%Y%m"
    when :year
      "%Y"
    else
      raise "Invalid interval length: #{length}"
    end
  end
end

class ActiveRecord::Relation
  def timed_interval(length, amount=1)
    @records = self.to_a.timed_interval(length, amount)
  end
end
