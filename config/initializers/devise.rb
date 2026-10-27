Devise.setup do |config|
  require "devise/orm/active_record"
  config.mailer_sender = ENV.fetch("MAILER_FROM", "photobook@example.com")
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.skip_session_storage = [ :http_auth ]
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 8..128
  config.paranoid = true
  config.reconfirmable = false
  config.expire_all_remember_me_on_sign_out = true
  config.rememberable_options = { httponly: true, same_site: :lax, secure: Rails.env.production? }
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other
end
