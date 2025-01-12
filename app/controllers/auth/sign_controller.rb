module Auth
  class SignController < BaseController
    before_action :check_login, except: [:logout]
    skip_after_action :set_auth_token, only: [:logout]
    before_action :set_oauth_user, only: [:bind, :direct, :bind_create, :sign]
    before_action :set_account, only: [:token]
    before_action :set_confirmed_account, only: [:sign, :login], if: -> { params[:identity].present? }

    def sign
      if params[:identity]
        if @account && @account.user && @account.user.password_digest.present?
          render 'sign_login'
        else
          @account = Account.find_by(identity: params[:identity].strip)
          render 'sign_join'
        end
      else
        render 'sign'
      end
    end

    def code
      @verify_token = VerifyToken.build_with_identity(params[:identity])

      if @verify_token.send_out!
        render 'code', locals: { message: t('.sent') }
      else
        render 'code_token', locals: { message: @verity_token.error_text }, status: :bad_request
      end
    end

    def bind
    end

    def bind_create
      @oauth_user.can_login?(login_params)
    end

    def join
      @account = Account.build_with_identity(params[:identity])

      if @account.can_login_by_token?(params[:token], **login_params)
        login_by_account @account

        render_login
      else
        flash.now[:error] = @account.error_text.presence || @account.user.error_text
        render 'alert', status: :unauthorized
      end
    end

    def login
      if @account.can_login_by_password?(params[:password])
        login_by_account @account

        render_login
      else
        flash.now[:error] = @account.error_text.presence || @account.user.error_text
        render 'alert', status: :unauthorized
      end
    end

    def token_login
      @verify_token = VerifyToken.build_with_identity(params[:identity])

      if @verify_token.send_out!
        render 'token_login', locals: { message: t('.sent') }
      end
    end

    def token
      if @account.can_login_by_token?(params[:token], **token_params)
        login_by_account @account

        render_login
      else
        flash.now[:error] = @account.error_text.presence || @account.user.error_text
        render 'alert', status: :unauthorized
      end
    end

    def logout
      current_authorized_token&.destroy
      session.delete :auth_token
    end

    private
    def set_account
      @account = Account.find_by(identity: params[:identity].strip)
    end

    def set_confirmed_account
      @account = Account.where(identity: params[:identity].strip).confirmed.with_user.take
    end

    def set_oauth_user
      @oauth_user = OauthUser.find_by uid: params[:uid]
    end

    def password_params
      params.permit(:password)
    end

    def token_params
      params.permit(:token)
    end

    def login_params
      q = params.permit(
        :name,
        :identity,
        :password,
        :password_confirmation,
        :token,
        :invited_code,
        :uid,
        :device_id  # ios设备注册
      )
      q[:identity].strip!

      if session[:return_to]
        r = URI.decode_www_form(URI(session[:return_to]).query.to_s).to_h
        q.merge! invited_code: r['invited_code'] if r.key?('invited_code')
      end

      if request.format.json?
        q.merge! source: 'api'
      else
        q.merge! source: 'web'
      end
      q
    end

    def render_login
      state = Com::State.find_by(id: params[:state])
      if state&.get?
        state.update user_id: current_user.id, destroyable: true
        render 'state_visit_get', layout: 'raw', locals: { state: state }, message: t('.success')
      elsif state
        render 'state_visit', layout: 'raw', locals: { state: state }, message: t('.success')
      else
        render 'visit', layout: 'raw', locals: { url:  url_for(RailsAuth.config.default_return_hash || { controller: '/home' }) }, message: t('.success')
      end
    end

    def check_login
      if current_user && !request.format.json?
        redirect_to RailsAuth.config.default_home_path
      end
    end

  end
end
