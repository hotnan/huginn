module PinterestConcern
  extend ActiveSupport::Concern

  # included do
  #   include Oauthable

  #   validate :validate_pinterest_options
  #   valid_oauth_providers :pinterest

  #   gem_dependency_check { defined?(Pinterest) && Devise.omniauth_providers.include?(:pinterest) && ENV['PINTEREST_OAUTH_KEY'].present? && ENV['PINTEREST_OAUTH_SECRET'].present? }
  # end

  # def validate_pinterest_options
  #   unless pinterest_consumer_key.present? &&
  #     pinterest_consumer_secret.present? &&
  #     pinterest_oauth_token.present? &&
  #     pinterest_oauth_token_secret.present?
  #     errors.add(:base, "Pinterest consumer_key, consumer_secret, oauth_token, and oauth_token_secret are required to authenticate with the Pinterest API.  You can provide these as options to this Agent, or as Credentials with the same names, but starting with 'pinterest'.")
  #   end
  # end

  # def pinterest_consumer_key
  #   (config = Devise.omniauth_configs[:pinterest]) && config.strategy.consumer_key
  # end

  # def pinterest_consumer_secret
  #   (config = Devise.omniauth_configs[:pinterest]) && config.strategy.consumer_secret
  # end

  # def pinterest_oauth_token
  #   service && service.token
  # end

  # def pinterest_oauth_token_secret
  #   service && service.secret
  # end

  # def pinterest
  #   @pinterest ||= Pinterest::REST::Client.new do |config|
  #     config.consumer_key = pinterest_consumer_key
  #     config.consumer_secret = pinterest_consumer_secret
  #     config.access_token = pinterest_oauth_token
  #     config.access_token_secret = pinterest_oauth_token_secret
  #   end
  # end

  # module ClassMethods
  #   def pinterest_dependencies_missing
  #     if ENV['PINTEREST_OAUTH_KEY'].blank? || ENV['PINTEREST_OAUTH_SECRET'].blank?
  #       "## Set PINTEREST_OAUTH_KEY and PINTEREST_OAUTH_SECRET in your environment to use Pinterest Agents."
  #     elsif !defined?(Pinterest) || !Devise.omniauth_providers.include?(:pinterest)
  #       "## Include the `pinterest`, `omniauth-pinterest` gems in your Gemfile to use Pinterest Agents."
  #     end
  #   end
  # end

  included do
    # include Oauthable

    # valid_oauth_providers :pinterest
  end

  def pinterest_consumer_key
    ENV['PINTEREST_OAUTH_KEY']
  end

  def pinterest_consumer_secret
    ENV['PINTEREST_OAUTH_SECRET']
  end

  def pinterest_oauth_token
    service.token
  end

  def pinterest_oauth_token_secret
    service.secret
  end

  def pinterest
    Pinterest.configure do |config|
      config.consumer_key = pinterest_consumer_key
      config.consumer_secret = pinterest_consumer_secret
      config.oauth_token = pinterest_oauth_token
      config.oauth_token_secret = pinterest_oauth_token_secret
    end
    
    Pinterest::Client.new
  end
end
