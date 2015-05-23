class ProfilesController < ApplicationController

  before_action :authenticate_user!
  before_action :ensure_admin, except: [:edit, :update, :show]
  before_action :ensure_admin_or_self, only: [:edit, :update, :show]
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.all
  end

  def show
  end

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to profile_path(@user), notice: 'User was successfully created.'
    else
      render :new
    end
  end

  def update
    if @user.update(user_params)
      redirect_to profile_path(@user), notice: 'User was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to profiles_url, notice: 'User was successfully destroyed.'
  end

  private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      if params and params[:user] and params[:user][:password] and params[:user][:password].blank?
        params[:user].delete :password
        params[:user].delete :password_confirmation
      end
      if current_user.is_admin
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :is_issuer, :is_admin)
      else
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end
    end

    def ensure_admin_or_self
      ensure_admin unless user_signed_in? and current_user.id == params[:id].to_i
    end

end
