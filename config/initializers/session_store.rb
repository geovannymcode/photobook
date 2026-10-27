Rails.application.config.session_store :cookie_store,
  key: "_photobook_session_v2", httponly: true, same_site: :lax,
  secure: Rails.env.production?, expire_after: 2.weeks
