class AccountsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_user
  before_action :set_account, only: [:show, :destroy]

  respond_to :html

  def index
    @accounts = @user.accounts
    respond_with(@accounts)
  end

  def sync
    parms = sync_params
    session[:sync_username] = parms[:sync_username]
    session[:sync_password] = parms[:sync_password]
    session[:bank_session_key], @accounts = @user.sync_accounts(parms)
    redirect_to user_accounts_path(@user), notice: 'Accounts successfully synchronized.'
  end

  def show
    respond_with(@account)
  end

  def destroy
    @account.destroy
    redirect_to user_accounts_path(@user)
  end

  private
    def set_account
      @account = Account.find(params[:id])
    end

    def account_params
      params.require(:account).permit(:type, :number, :index_string)
    end

    def set_user
      @user = User.find(params[:user_id])
    end

    def sync_params
      params.permit(:sync_username, :sync_password)
    end
end
