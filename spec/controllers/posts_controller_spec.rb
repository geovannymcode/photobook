require 'rails_helper'

RSpec.describe PostsController, type: :controller do

  describe "GET #index" do

    it "responds successfully with an HTTP 200 status code" do
      get :index
      expect(response).to be_success
      expect(response).to have_http_status(200)
    end

  end

describe "GET #new" do

  context "without authentication" do
    it "redirects to login page" do
      get :new
      expect(response).to redirect_to new_user_session_path
    end
  end

  context "with authentication" do
    before(:each) do
      sign_in create(:user)
    end

    it "get new template" do
      get :new
      expect(response).to render_template("new")
    end
  end

end

describe "POST #create" do

  context "without authentication" do
    it "redirects to login page" do
      post :create
      expect(response).to redirect_to new_user_session_path
    end
  end

  context "with authentication" do
    before(:each) do
      sign_in :user, create(:user)
    end

    it "create new post" do
      expect(subject.current_user).to_not eq(nil)

      expect{
        post :create, post: attributes_for(:post)
      }.to change(Post,:count).by(1)

    end
  end

end

end