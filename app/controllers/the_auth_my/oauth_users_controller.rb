class RailsAuthMy::OauthUsersController < RailsAuthMy::BaseController
  before_action :set_user
  before_action :set_oauth_user, only: [:show, :edit, :update, :destroy]

  def index
    @oauth_users = current_user.oauth_users
  end

  def show
  end

  def new
    @oauth_user = OauthUser.new
  end

  def edit
  end

  def create
    @oauth_user = OauthUser.new(oauth_user_params)

    respond_to do |format|
      if @oauth_user.save
        format.html { redirect_to @oauth_user, notice: 'Oauth user was successfully created.' }
        format.json { render :show, status: :created, location: @oauth_user }
      else
        format.html { render :new }
        format.json { render json: @oauth_user.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @oauth_user.update(oauth_user_params)
        format.html { redirect_to @oauth_user, notice: 'Oauth user was successfully updated.' }
        format.json { render :show, status: :ok, location: @oauth_user }
      else
        format.html { render :edit }
        format.json { render json: @oauth_user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @oauth_user.destroy
    respond_to do |format|
      format.html { redirect_to my_oauth_users_url, notice: 'Oauth user was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  def set_user
    @user = current_user
  end

  def set_oauth_user
    @oauth_user = OauthUser.find(params[:id])
  end

  def oauth_user_params
    params.fetch(:oauth_user, {})
  end

end
