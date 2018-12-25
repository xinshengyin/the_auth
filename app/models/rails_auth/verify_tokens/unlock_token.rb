class UnlockToken < VerifyToken

  def update_token
    self.token = SecureRandom.uuid
    self.expired_at = 10.minutes.since
  end

end unless RailsAuth.config.disabled_models.include?('UnlockToken')
