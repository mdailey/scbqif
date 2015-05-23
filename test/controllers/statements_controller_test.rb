require 'test_helper'

class StatementsControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  setup do
    @statement = statements(:one)
  end

  test "should authorize show statement" do
    get :show, id: @statement, account_id: @statement.account, user_id: @statement.account.user
    assert_redirected_to new_user_session_path
  end

  test "should show statement" do
    sign_in users(:one)
    get :show, id: @statement, account_id: @statement.account, user_id: @statement.account.user
    assert_response :success
  end

  test "should destroy statement" do
    sign_in users(:one)
    assert_difference('Statement.count', -1) do
      delete :destroy, id: @statement, account_id: @statement.account, user_id: @statement.account.user
    end
    assert_redirected_to user_account_path(@statement.account.user, @statement.account)
  end

  test "should authorize destroy statement" do
    assert_difference('Statement.count', 0) do
      delete :destroy, id: @statement, account_id: @statement.account, user_id: @statement.account.user
    end
    assert_redirected_to new_user_session_path
  end
end
