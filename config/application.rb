require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DriSpotlight
  class Application < Rails::Application
    config.action_mailer.default_url_options = { host: "localhost:3000", from: "noreply@example.com" }
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1
    config.autoloader = :classic
    #config.active_record.verbose_query_logs = true
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.repository_base = 'https://repository.dri.ie'
  end
end
