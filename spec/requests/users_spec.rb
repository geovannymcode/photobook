require "rails_helper"

RSpec.describe "Users", type: :request do
  it "registers with all profile fields" do
    attrs = attributes_for(:user).merge(location: "The wall", biography: "Photographer")
    expect { post user_registration_path, params: { user: attrs } }.to change(User, :count).by(1)
    expect(response).to redirect_to(root_path)
    expect(User.last.location).to eq("The wall")
  end

  it "rejects malformed email and missing profile fields" do
    expect {
      post user_registration_path, params: { user: attributes_for(:user).merge(email: "invalid", username: "", firstname: "", lastname: "") }
    }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "logs in and out" do
    user = create(:user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    get new_post_path
    expect(response).to have_http_status(:ok)
    delete destroy_user_session_path
    get new_post_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "resets a password through the emailed token" do
    user = create(:user)
    ActionMailer::Base.deliveries.clear
    post user_password_path, params: { user: { email: user.email } }
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ user.email ])
    token = mail.body.encoded[/reset_password_token=([^"&<\s]+)/, 1]
    expect(token).to be_present
    put user_password_path, params: { user: { reset_password_token: token, password: "newpassword123", password_confirmation: "newpassword123" } }
    expect(user.reload.valid_password?("newpassword123")).to be(true)
  end

  it "requires the current password to edit an account" do
    user = create(:user)
    sign_in user
    put user_registration_path, params: { user: { email: "changed@example.com", current_password: "wrong" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email).not_to eq("changed@example.com")
  end
  it "authenticates an existing bcrypt hash with a legacy six-character password" do
    user = create(:user)
    user.update_column(:encrypted_password, Devise::Encryptor.digest(User, "123456"))
    post user_session_path, params: { user: { email: user.email, password: "123456" } }
    get new_post_path
    expect(response).to have_http_status(:ok)
  end
end
