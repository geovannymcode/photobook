require "rails_helper"

RSpec.describe "CSRF protection", type: :request do
  around do |example|
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  it "rejects login without a CSRF token" do
    user = create(:user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
