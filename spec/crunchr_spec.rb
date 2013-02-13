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
  zero: 0.0,
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
  prev_rabbit = rand(10)
  3.times do
    list << TestClass.new(
      rabbits: prev_rabbit += rand(10), dogs: rand(20), cats: rand(40)
    )
  end
  list
end

describe "Crunchr" do
  subject {
    TestClass.new
  }

  context "The basics" do
    before(:each) do
      subject.data = { doors: 10, keys: 8, null: 0.00 }
    end

    it "fetches door" do
      subject.fetch("doors").should == 10
    end

    it "fetches zero values" do
      subject.fetch("null").should == 0.0
    end

    it "calls calculate when a stmt is present" do
      subject.expects(:calculate)
      subject.fetch("keys - doors")
    end

    it "calculates the right value" do
      subject.fetch("keys - doors").should == -2
    end

    it "returns nil for non existing" do
      subject.fetch("n'existe pas").should be_nil
    end

    it "return nil for non-numeric/hash values" do
      subject.data[:hash] = { :depth => 2 }
      subject.data[:arrray] = [ 1, 2 ]

      subject.fetch("hash").should == { :depth => 2 }
      subject.fetch("array").should be_nil
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

      TestClass.as_table(@list, keys: ['dogs', 'cats - dogs']).should == expected
    end

    it "should make delta tables" do
      expected = [
        [ @list[0].data[:rabbits] ],
        [ @list[1].data[:rabbits] - @list[0].data[:rabbits] ],
        [ @list[2].data[:rabbits] - @list[1].data[:rabbits] ],
      ]

      TestClass.as_table(@list, keys: ['rabbits'], delta: true).should == expected
    end
  end

  context "2d tables" do
    before(:each) do
      @list = []
      3.times do
        @list << gen_table_list
      end
    end

    it "should flatten the list with the sum operator" do
      res = TestClass.as_table(@list, keys: ['dogs - cats'], list_operator: :sum)
      res.should == [
        [ @list[0][0].data[:dogs] - @list[0][0].data[:cats] +
          @list[0][1].data[:dogs] - @list[0][1].data[:cats] +
          @list[0][2].data[:dogs] - @list[0][2].data[:cats]
        ],
        [ @list[1][0].data[:dogs] - @list[1][0].data[:cats] +
          @list[1][1].data[:dogs] - @list[1][1].data[:cats] +
          @list[1][2].data[:dogs] - @list[1][2].data[:cats]
        ],
        [ @list[2][0].data[:dogs] - @list[2][0].data[:cats] +
          @list[2][1].data[:dogs] - @list[2][1].data[:cats] +
          @list[2][2].data[:dogs] - @list[2][2].data[:cats]
        ],
      ]
    end

    it "should flatten the list with the mean operator" do
      res = TestClass.as_table(@list, keys: ['dogs - cats'], list_operator: :mean)
      res.should == [
        [ ( @list[0][0].data[:dogs] - @list[0][0].data[:cats] +
            @list[0][1].data[:dogs] - @list[0][1].data[:cats] +
            @list[0][2].data[:dogs] - @list[0][2].data[:cats] ) / 3.0
        ],
        [ ( @list[1][0].data[:dogs] - @list[1][0].data[:cats] +
            @list[1][1].data[:dogs] - @list[1][1].data[:cats] +
            @list[1][2].data[:dogs] - @list[1][2].data[:cats] ) / 3.0
        ],
        [ ( @list[2][0].data[:dogs] - @list[2][0].data[:cats] +
            @list[2][1].data[:dogs] - @list[2][1].data[:cats] +
            @list[2][2].data[:dogs] - @list[2][2].data[:cats] ) / 3.0
        ],
      ]
    end
  end

  context "Deltas" do
    before(:each) do
      subject.data = deep_hash
    end

    it "should delta one object with another" do
      comp = TestClass.new(deep_hash)
      delta = subject.delta(comp)

      delta.should be_kind_of(TestClass)
      delta.data.should be_kind_of(Hash)
      delta.data.should_not be_empty
    end

    it "should substract" do
      comp = TestClass.new(deep_hash)
      delta = subject.delta(comp)
      delta.fetch("loans/requested/GBP").should == 0.0
    end

  end

  context "Extended calculations" do
    before(:each) do
      subject.data = deep_hash
    end

    it "performs calculations successively" do
      subject.fetch("(loans/requested/GBP + loans/payed/GBP) - commission/pending/GBP").should == (0.65395 + 145.23) - 1.3079
    end

    it "handles nested groupings" do
      subject.fetch("((users/count + users/active) + users/active) + users/count").should == (((14 + 2) + 2) + 14).to_f
    end

    it "ignores malformed groupings" do
      subject.fetch("(users/count + users/active").should == 2.0  # 0 + 2
      subject.fetch("((users/count + users/active) + 12").should == 12.0
    end
  end
end
