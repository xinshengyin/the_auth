require 'jwt'
module Auth
  module Controller::Application
    extend ActiveSupport::Concern

    included do
      helper_method :current_user, :current_client, :current_account, :current_authorized_token
      after_action :set_auth_token
    end

    def require_login(return_to: nil)
      return if current_user
      url = store_location(return_to)
      if current_authorized_token&.oauth_user
        @code = 'oauth_user'
      elsif current_authorized_token&.account
        @code = 'account'
      else
        @code = 'authorized_token'
      end

      if request.variant.include?(:mini_program)
        render 'require_program_login', locals: { url: url }
      else
        redirect_to url_for(controller: '/auth/sign', action: 'sign', identity: params[:identity])
      end
    end

    def require_authorized_token
      return if current_authorized_token
      @code = 'authorized_token'

      render 'require_authorized_token', status: 401
    end

    def client_params
      if current_client
        { member_id: current_client.id }
      elsif current_user
        { user_id: current_user.id, member_id: nil }
      else
        { user_id: nil, member_id: nil }
      end
    end

    def current_client
      return @current_client if defined?(@current_client)
      @current_client = current_authorized_token&.member
      logger.debug "\e[35m  Current Client: #{@current_client&.id}  \e[0m"
      @current_client
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_account&.user
      logger.debug "\e[35m  Current User: #{@current_user&.id}  \e[0m"
      @current_user
    end

    def current_account
      return @current_account if defined?(@current_account)

      if params[:disposable_token].present?
        begin
          DisposableToken.transaction do
            dt = DisposableToken.lock(true).find(params[:disposable_token])
            dt.used_at = Time.current
            dt.save!
            @current_account = dt.account
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Com::DisposableTokenError
        end
      else
        @current_account = current_authorized_token&.account
      end

      logger.debug "\e[35m  Login as account: #{@current_account&.id}  \e[0m"
      @current_account
    end

    def current_authorized_token
      return @current_authorized_token if defined?(@current_authorized_token)
      token = params[:auth_token].presence || request.headers['Authorization'].to_s.split(' ').last.presence || session[:auth_token]

      return unless token
      @current_authorized_token = AuthorizedToken.find_by(token: token)
      logger.debug "\e[35m  Current Authorized Token: #{@current_authorized_token&.id}  \e[0m"
      @current_authorized_token
    end

    def store_location(path = nil)
      if path
        session[:return_to] = path
      elsif request.get?
        session[:return_to] = request.url
      else
        session[:return_to] = request.referer
        session[:request_method] = request.method
        session[:request_body] = request.request_parameters
      end
      session[:request_route] = request.path_parameters.merge(request.query_parameters).except(:business, :namespace)

      r_path = URI(session[:return_to].to_s).path.delete_suffix('/')
      if RailsAuth.config.ignore_return_paths.include?(r_path)
        session[:return_to] = RailsAuth.config.default_return_path
      else
        session[:return_to]
      end
    end

    def login_by_account(account)
      @current_account = account
      if params[:uid]
        oauth_user = OauthUser.find_by uid: params[:uid]
        oauth_user.update identity: params[:identity]
      end
      set_login_var

      logger.debug "\e[35m  Login by account #{account.id} as user: #{account.user_id}  \e[0m"
    end

    def login_by_token
      token = Auth::AuthorizedToken.find_by token: params[:auth_token]
      if token
        account = token.account
        account.user || account.build_user
        account.confirmed = true
        account.save

        login_by_account(account)
      end
    end

    private
    def set_login_var
      @current_user = @current_account.user
      @current_authorized_token = @current_account.authorized_token
    end

    def set_auth_token
      return unless defined?(@current_account) && @current_account

      token = @current_account.auth_token
      headers['Authorization'] = token
      session[:auth_token] = token
      logger.debug "\e[35m  Set session Auth token: #{session[:auth_token]}  \e[0m"
    end

  end
end
