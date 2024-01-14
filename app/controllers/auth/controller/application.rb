module Auth
  module Controller::Application
    extend ActiveSupport::Concern

    included do
      helper_method :current_user, :current_client, :current_account, :current_authorized_token
      after_action :set_auth_token
    end

    def require_user(app = nil)
      return if current_user

      redirect_to url_for(controller: '/auth/sign', action: 'sign', identity: params[:identity], state: urlsafe_encode64(destroyable: false))
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_authorized_token&.user
      logger.debug "\e[35m  Current User: #{@current_user&.id}  \e[0m"
      @current_user
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

    def require_client
      return if current_client

      render 'require_client', layout: 'raw', locals: { url: url_for(state: urlsafe_encode64(destroyable: false)) }
    end

    def current_client
      return @current_client if defined?(@current_client)
      return unless current_account
      @current_client = current_authorized_token&.member
      logger.debug "\e[35m  Current Client: #{@current_client&.id}  \e[0m"
      @current_client
    end

    def current_account
      return @current_account if defined?(@current_account)
      @current_account = current_authorized_token&.account
      logger.debug "\e[35m  Login as account: #{@current_account&.id}  \e[0m"
      @current_account
    end

    def current_authorized_token
      return @current_authorized_token if defined?(@current_authorized_token)
      token = params[:auth_token].presence || request.headers['Authorization'].to_s.split(' ').last.presence || session[:auth_token]

      return unless token
      authorized_token = AuthorizedToken.find_by(id: token)
      if authorized_token&.expired?
        @current_authorized_token = authorized_token.refresh
      elsif authorized_token.nil?
        session.delete :auth_token
      else
        @current_authorized_token = authorized_token
      end
      logger.debug "\e[35m  Current Authorized Token: #{@current_authorized_token&.id}, Destroyed: #{@current_authorized_token&.destroyed?}  \e[0m"
      @current_authorized_token
    end

    def login_by_account(account)
      @current_account = account
      @current_user = @current_account.user
      @current_authorized_token = @current_account.authorized_token

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
    def set_auth_token
      return unless defined?(@current_authorized_token) && @current_authorized_token

      headers['Authorization'] = @current_authorized_token.id
      session[:auth_token] = @current_authorized_token.id
      logger.debug "\e[35m  Set session Auth token: #{session[:auth_token]}  \e[0m"
    end

  end
end
