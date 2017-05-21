class UsersController < ApplicationController
  before_action -> { authorize!(:manage_users) }
  before_action :set_user, only: %i[edit update]

  def index
    @users = User.includes(:sites).order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "ユーザーを登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = user_params
    attrs = attrs.except(:password) if attrs[:password].blank?
    if @user == Current.user && (attrs[:active] == "0" || attrs[:role] != @user.role)
      return redirect_to(edit_user_path(@user), alert: "自分自身の権限・有効状態は変更できません。")
    end

    if @user.update(attrs)
      redirect_to users_path, notice: "更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user = @user = User.find(params[:id])
  def user_params = params.require(:user).permit(:name, :email_address, :role, :active, :password, site_ids: [])
end
