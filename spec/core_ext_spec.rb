require 'spec_helper'

describe "Crunchr::CoreExt" do
  describe Hash do
    it "should delta two hashes" do
      a = { a: 4, b: 1 }
      a.delta({ a: 2, b: 2 }).should == { a: 2, b: -1 }
    end
  end

  describe Array do
    it "should sum the values" do
      [ 1, 2, 3 ].sum.should == 6.0
      [ 1, true, 3 ].sum.should == 4.0
      [ "a", "b", "c" ].sum.should == 0.0
    end

    it "should mean the values" do
      [ 1, 2, 3, 4 ].mean.should == [ 1, 2, 3, 4 ].sum / 4
    end

    it "should median the values" do
      [ 1, 2, 3, 4, 5 ].median.should == 3
      [ 1, 2, 3, 4 ].median.should == [2,3].mean
    end

    it "should range the values" do
      [ 2, 3, 4, 5, 6 ].range.should == 4
    end

    it "should mode the values" do
      [ 1, 1, 1, 1, 1, 2, 2, 2, 3, 3 ].mode.should == 1
    end

    it "should stddev the values" do
      ("%.4f" % [ 1, 2, 3, 4 ].stddev).should == "1.2910"
    end
  end
end
