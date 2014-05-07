require_dependency "auth/application_controller"

module Auth
  class UsersController < ApplicationController

    def new
      @user = Auth::User.new :password => '' # force client side validation patch
      referer = request.headers['X-XHR-Referer'] || request.referer
      store_location referer if referer.present?
    end

    def create
      @user = Auth::User.new user_params
      if @user.save
        env['warden'].set_user(@user)
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

  end
end
