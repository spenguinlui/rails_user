# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # You should configure your model like this:
  # devise :omniauthable, omniauth_providers: [:twitter]

  # You should also create an action method in this controller like this:
  # def twitter
  # end

  def google_oauth2
    Rails.logger.debug "------------- 回到 Rails -------------"
    @user = User.find_for_google_oauth2(request.env["omniauth.auth"], current_user)

    Rails.logger.debug "------------- 取得 User -------------"

    # 判斷是否已存在資料庫
    if @user.persisted?
      Rails.logger.debug "------------- User 已存在 -------------"
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
      sign_in_and_redirect @user, :event => :authentication
    else
      Rails.logger.debug "------------- User 不存在 -------------"
      session["devise.google_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  def facebook
    Rails.logger.debug "------------- 回到 Rails -------------"
    @user = User.find_for_fb_omniauth(request.env["omniauth.auth"])

    Rails.logger.debug "------------- 取得 User -------------"

    if @user.persisted?
      Rails.logger.debug "------------- User 已存在 -------------"
      sign_in_and_redirect @user, event: :authentication #this will throw if @user is not activated
      set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
    else
      Rails.logger.debug "------------- User 不存在 -------------"
      session["devise.facebook_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  def line
    Rails.logger.debug "------------- 回到 Rails -------------"
    @user = User.find_for_line_omniauth(request.env["omniauth.auth"], current_user)

    Rails.logger.debug "------------- 取得 User -------------"

    if @user.persisted?
      Rails.logger.debug "------------- User 已存在 -------------"
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Line"
      sign_in_and_redirect @user, event: :authentication #this will throw if @user is not activated
    else
      Rails.logger.debug "------------- User 不存在 -------------"
      session["devise.line_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path, alert: "無法獲得驗證！"
  end

  # More info at:
  # https://github.com/heartcombo/devise#omniauth

  # GET|POST /resource/auth/twitter
  # def passthru
  #   super
  # end

  # GET|POST /users/auth/twitter/callback
  # def failure
  #   super
  # end

  # protected

  # The path used when OmniAuth fails
  # def after_omniauth_failure_path_for(scope)
  #   super(scope)
  # end
end
