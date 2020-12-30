# README

以 Ruby on Rails devise 建立結合第三方登入的 User 系統

## 配置需求
### 主要系統
* ruby version 2.6.3
* rails version ~> 6.0.3
* mkcert
* nss
### Gem dependencies
使用者系統
* [devise](https://github.com/heartcombo/devise)

第三方認證
* [omniauth](https://github.com/omniauth/omniauth)
* [omniauth-facebook](https://github.com/simi/omniauth-facebook)
* [omniauth-google-oauth2](https://github.com/zquestz/omniauth-google-oauth2)

開發用途
* [dotenv-rails](https://github.com/bkeepers/dotenv)
* [awesome_print](https://github.com/awesome-print/awesome_print)
* [letter_opener](https://github.com/ryanb/letter_opener)

### 第三方認證 API 授權
可以到各平台申請帳號登入授權
[facebook](https://developers.facebook.com/)
登入開發者模式，建立專案即可。在左方設定 > 基本資料可以取得
client_id = 應用程式編號
client_secret = 應用程式密鑰
[google](https://console.cloud.google.com/)
也是成立一個專案，但要先設定同意頁面，再申請憑證
client_id = 用戶端編號
client_secret = 用戶端密碼

## 製作流程
### 建立 devise in rails 專案
建立 rails 專案
`rails new rails_user`

安裝 devise
`rails g devise:install`

建立 User model
`rails g devise user`
`rails db:migrate`

加入第三方所需的欄位(也可以在第一次 migrate 前就加入)
`rails generate migration add_omniauth_to_users`
```ruby=
def change
    add_column :users, :name, :string
    add_column :users, :fb_uid, :string
    add_column :users, :fb_token, :string
    add_column :users, :google_uid, :string
    add_column :users, :google_token, :string
end
```
`rails db:migrate`

### 設定第三方登入
設定 route
```ruby=
devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
```
devise omniauth 要根據第三方有相對應的設定，使用環境變數，**＊註1**
devise.rb:
```ruby=
config.omniauth :facebook, ENV['FACEBOOK_CLIENT_ID'], ENV['FACEBOOK_CLIENT_SECRET'], scope: "public_profile,email", info_fields: "email,name"     
config.omniauth :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], { access_type: "offline", approval_prompt: "" }
```
views sign_in/sign_up 畫面應該就會有第三方登入按鈕，點擊後會 redirect 到第三方平台認證，有些平台會限制一定要 https連線 **＊註2**，然後再 redirect 到下面的路由 **＊註3**

會檢查第三方登入後回傳的資訊，找到符合的 User
omniauth_callbacks_controller.rb:
```ruby=
def google_oauth2
  @user = User.find_for_google_oauth2(request.env["omniauth.auth"], current_user)

  if @user.persisted?
    flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
    sign_in_and_redirect @user, :event => :authentication
  else
    session["devise.google_data"] = request.env["omniauth.auth"]
    redirect_to new_user_registration_url
  end
end

def facebook
  @user = User.from_omniauth(request.env["omniauth.auth"])

  if @user.persisted?
    sign_in_and_redirect @user, event: :authentication #this will throw if @user is not activated
    set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
  else
    session["devise.facebook_data"] = request.env["omniauth.auth"]
    redirect_to new_user_registration_url
  end
end

def failure
  redirect_to root_path, alert: "無法獲得驗證！"
end
```

User 加入配合方法 find_for_google_oauth2、from_omniauth
以回傳的 token、uid 找到 user，如果沒有(第一次登入)便建立 user
user.rb:
```ruby=
# 登入要結合 omniauth
devise :omniauthable, omniauth_providers: [:facebook, :google_oauth2]

def self.find_for_google_oauth2(access_token, signed_in_resource=nil)
    data = access_token.info
    user = User.where(:google_token => access_token.credentials.token, :google_uid => access_token.uid ).first    
    if user
      return user
    else
      existing_user = User.where(:email => data["email"]).first
      if  existing_user
        existing_user.google_uid = access_token.uid
        existing_user.google_token = access_token.credentials.token
        existing_user.save!
        return existing_user
      else
        user = User.create(
            name: data["name"],
            email: data["email"],
            password: Devise.friendly_token[0,20],
            google_token: access_token.credentials.token,
            google_uid: access_token.uid
          )
      end
    end
end

def self.from_omniauth(auth)
    # Case 1: Find existing user by facebook uid
    user = User.find_by_fb_uid( auth.uid )
    if user
      user.fb_token = auth.credentials.token
      user.save!
      return user
    end
    # Case 2: Find existing user by email
    existing_user = User.find_by_email( auth.info.email )
    if existing_user
      existing_user.fb_uid = auth.uid
      existing_user.fb_token = auth.credentials.token
      existing_user.save!
      return existing_user
    end
    # Case 3: Create new password
    user = User.new
    user.fb_uid = auth.uid
    user.fb_token = auth.credentials.token
    user.email = auth.info.email
    user.password = Devise.friendly_token[0,20]
    user.name = auth.info.name
    user.save!
    return user
end
```
### 注意事項
#### 註1
第三方 API 的 id、key 等重要資訊要放在環境變數中

安裝 `gem 'dotenv-rails'`，並在專案 root 建立 `.env` 檔
將需要的環境變數以 `FACEBOOK_CLIENT_ID=xxxx` 定義
引入時用 `ENV['FACEBOOK_CLIENT_ID']` 即可

#### 註2
由於某些第三方平台限定 https(ssl) 連線，但開發模式一定是設定本機，
因此需要自己發簽證給自己，建立 https 連線

安裝 `brew install mkcert` or `brew install mkcert nss`
如果是使用 firefox 需要安裝 nss

到專案根目錄下輸入 `mkcert localhost`，簽署憑證
再來把得到的憑證放到 config/ssl 資料夾
```
mkdir config/ssl
mv localhost-key.pem localhost.pem config/ssl
```
然後更改 rails sever 設定
config/application.rb:
```ruby=
# 限制所有連線都是 ssl
config.force_ssl = true
```
config/puma.rb:
刪掉原本的
```ruby=
port        ENV.fetch('PORT') { 3000 }
environment ENV.fetch('RAILS_ENV') { 'development' }
```
並加上
```ruby=
# 本來預設 server run 在 3000 port，改成如果是 development 就去認證 ssl
if ENV.fetch('RAILS_ENV') { 'development' } == 'development'
  # using mkcert self-signed cert enable ssl
  ssl_bind '0.0.0.0', ENV.fetch('PORT') { 8080 }, cert: 'config/ssl/localhost.pem', key: 'config/ssl/localhost-key.pem'
else
  port        ENV.fetch('PORT') { 3000 }
  environment ENV.fetch('RAILS_ENV') { 'development' }
end
```
port 預設改成 8080，為了第三方登入用
再來打 `rails s` 就會開啟 https://localhost:8080 了(不用 `-p 8080`)

#### 註3
連到第三方認證後，需要給第三方平台一個認證回導回的網址，不然會出現 redirect_uri 的錯誤
##### facebook
![](https://i.imgur.com/uHNQIq8.png)

##### google
![](https://i.imgur.com/TjROHqi.png)

## 參考網站

> https://cindyliu923.medium.com/rails-devise-google-fecebook%E7%99%BB%E5%85%A5%E5%AF%A6%E4%BD%9C-ebfb3170b0a8
> https://medium.com/%E4%BA%BA%E7%94%9F%E6%AF%94%E5%AF%AB-code-%E9%9B%A3%E4%B8%80%E9%BB%9E%E9%BB%9E/rails-%E5%9C%A8%E9%96%8B%E7%99%BC%E7%92%B0%E5%A2%83%E4%B8%AD%E5%95%9F%E7%94%A8-https-74741d3b5183