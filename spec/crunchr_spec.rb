require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class TestClass
  attr_accessor :data
  include Crunchr

  def initialize(data={})
    @data = data
  end
end

deep_hash = {
  users: { count: 14, active: 2},
  loans: {
    requested: { EUR: 781.284599, GBP: 0.65395, USD: 0.65395, AWG: 0.65395 },
    payed: { EUR: 130.42, GBP: 145.23 }
  },
  orders: { count: 8, lines: 14 },
  commission: {
    approved: { EUR: 32.56 },
    pending: { EUR: 0.8492, GBP: 1.3079, USD: 1.3079, AWG: 1.3079, JPY: 1.3079 }
  },
}

def gen_table_list
  list = []
  3.times do
    list << TestClass.new( rabbits: rand(10), dogs: rand(20), cats: rand(40) )
  end
  list
end

describe "Crunchr" do
  subject {
    TestClass.new
  }

  context "The basics" do
    before(:each) do
      subject.data = { doors: 10, keys: 8 }
    end

    it "fetches door" do
      subject.fetch("doors").should == 10
    end

    it "calls calculate when a stmt is present" do
      subject.expects(:calculate)
      subject.fetch("keys - doors")
    end

    it "calculates the right value" do
      subject.fetch("keys - doors").should == -2
    end
  end

  context "Deep hashes" do
    before(:each) do
      subject.data = deep_hash
    end

    it "fetches deep keys" do
      subject.fetch("loans/requested/GBP").should == 0.65395
    end

    it "calculates deep keys" do
      subject.fetch("loans/requested/GBP + loans/payed/GBP").should == 0.65395 + 145.23
    end
  end

  context "1d tables" do
    before(:each) do
      @list = gen_table_list
    end

    it "should make a nice table" do
      expected = [
        [ @list[0].data[:dogs], @list[0].data[:cats] ],
        [ @list[1].data[:dogs], @list[1].data[:cats] ],
        [ @list[2].data[:dogs], @list[2].data[:cats] ],
      ]

      TestClass.as_table(@list, keys: %w[dogs cats]).should == expected
    end

    it "should make a calculated table" do
      expected = [
        [ @list[0].data[:dogs], @list[0].data[:cats] - @list[0].data[:dogs] ],
        [ @list[1].data[:dogs], @list[1].data[:cats] - @list[1].data[:dogs] ],
        [ @list[2].data[:dogs], @list[2].data[:cats] - @list[2].data[:dogs] ],
      ]

      TestClass.as_table(@list, keys: ['dogs' 'cats - dogs']).should == expected
    end

  end

  context "2d tables" do
  end
end
