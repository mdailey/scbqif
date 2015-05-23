require 'test_helper'

class AccountsControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  setup do
    @account = accounts(:one)
  end

  test "should authorize get index" do
    get :index, user_id: @account.user
    assert_redirected_to new_user_session_path
  end

  test "should get index" do
    sign_in users(:one)
    get :index, user_id: @account.user
    assert_response :success
    assert_not_nil assigns(:accounts)
  end

  test "should authorize show account" do
    get :show, id: @account, user_id: @account.user
    assert_redirected_to new_user_session_path
  end

  test "should show account" do
    sign_in users(:one)
    get :show, id: @account, user_id: @account.user
    assert_response :success
  end

  test "should destroy account" do
    sign_in users(:one)
    assert_difference('Account.count', -1) do
      delete :destroy, id: @account, user_id: @account.user
    end
    assert_redirected_to user_accounts_path(@account.user)
  end

  test "should authorize destroy account" do
    assert_difference('Account.count', 0) do
      delete :destroy, id: @account, user_id: @account.user
    end
    assert_redirected_to new_user_session_path
  end
end
