class HomeController < ApplicationController
  def index
    @user = current_user
    @users = User.all
  end

  def destroy
    user = User.find(params[:id])
    user.destroy
    redirect_to root_path
  end
end