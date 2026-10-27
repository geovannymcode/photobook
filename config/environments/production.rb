Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true
  config.log_level = :info
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))
  config.active_storage.service = :local
  config.cache_store = :memory_store
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST"), protocol: "https" }
  config.hosts = [ ENV.fetch("APP_HOST") ]
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"), port: ENV.fetch("SMTP_PORT", "587").to_i,
    user_name: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"],
    authentication: :plain, enable_starttls_auto: true
  }
  config.active_support.deprecation = :notify
  config.active_record.dump_schema_after_migration = false
end
