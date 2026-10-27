Rails.application.config.filter_parameters += [
  :password, :password_confirmation, :current_password, :email, :token,
  :secret, :authorization, :encrypted_password, :biography,
  :username, :firstname, :lastname, :location, :photo
]
