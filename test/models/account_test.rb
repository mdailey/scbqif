require 'test_helper'

class AccountTest < ActiveSupport::TestCase

  test "should be valid" do
    Account.all.each do |acct|
      assert acct.valid?
    end
  end

end
