class TheAuth::PasswordController < TheAuth::BaseController
  before_action :set_user, only: [:create]

  def new
  end

  def create
    if @user
      UserMailer.password_reset(@user).deliver_now
    else
      render :new, error: @user.errors.full_messages
    end
  end

  def edit
    @user = User.find_by(reset_token: params[:token])
    @user.clear_reset_token!
  end

  def update
  end

  private
  def set_user
    if params[:login].include?('@')
      @user = User.find_by(email: params[:login])
    else
      @user = User.find_by(mobile: params[:login])
    end
  end

  def inc_ip_count
    Rails.cache.write "login/#{request.remote_ip}", ip_count + 1, :expires_in => 60.seconds
  end

  def ip_count
    Rails.cache.read("login/#{request.remote_ip}").to_i
  end

  def require_recaptcha?
    ip_count >= 3
  end


  private
  def user_params
    params.require(:user).permit(:name,
                                 :email,
                                 :password,
                                 :password_confirmation)
  end

end