class StatementsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_user
  before_action :set_account
  before_action :set_statement, only: [:show, :edit, :update, :destroy, :sync_one]

  respond_to :html, :qif, :ofx

  def sync_all
    parms = sync_params
    session[:sync_username] = parms[:sync_username]
    session[:sync_password] = parms[:sync_password]
    session[:bank_session_key] = @account.sync_statements(parms, session[:bank_session_key])
    redirect_to user_account_path(@user, @account), notice: 'Statements successfully synchronized.'
  end

  def sync_one
    parms = sync_params
    session[:sync_username] ||= parms[:sync_username]
    session[:sync_password] ||= parms[:sync_password]
    sync_parms = { sync_username: session[:sync_username], sync_password: session[:sync_password], bank_session_key: session[:bank_session_key] }
    result_hash = @statement.sync_transactions(sync_parms)
    if result_hash[:error]
      redirect_to user_account_path(@user, @account), alert: result_hash[:error]
    else
      session[:bank_session_key] = result_hash[:session_key]
      redirect_to user_account_statement_path(@user, @account, @statement), notice: 'Transactions successfully synchronized.'
    end
  end

  def show
    if @statement.fetch_date.nil? or @statement.transactions.length == 0
      redirect_to user_account_path(@user, @account), notice: 'No transactions'
    else
      respond_to do |format|
        format.qif { send_file @statement.to_qif.path }
        format.ofx { send_file @statement.to_ofx.path }
        format.html { respond_with(@statement) }
      end
    end
  end

  def destroy
    @statement.destroy
    redirect_to user_account_path(@user, @account)
  end

  private

    def set_statement
      @statement = Statement.find(params[:id])
    end

    def statement_params
      params.require(:statement).permit(:issue_date, :fetch_date, :account_id)
    end

    def set_account
      @account = Account.find(params[:account_id])
    end

    def set_user
      @user = User.find(params[:user_id])
    end

    def sync_params
      params.permit(:sync_username, :sync_password)
    end

end
