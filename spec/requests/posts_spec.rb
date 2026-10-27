require "rails_helper"

RSpec.describe "Posts", type: :request do
  let(:owner) { create(:user) }
  let!(:post_record) { create(:post, user: owner) }
  let(:upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/factories/photobook.jpg"), "image/jpeg") }

  it "allows public index, show and JSON without exposing user credentials" do
    get posts_path
    expect(response).to have_http_status(:ok)
    get post_path(post_record)
    expect(response).to have_http_status(:ok)
    get post_path(post_record, format: :json)
    expect(JSON.parse(response.body).keys).to match_array(%w[id title description created_at updated_at])
  end

  it "shows exactly the ten newest posts" do
    11.times { |n| create(:post, title: "Photo #{n}") }
    get posts_path(format: :json)
    expect(JSON.parse(response.body).map { |p| p["id"] }).to eq(Post.recent.pluck(:id))
    expect(JSON.parse(response.body).size).to eq(10)
  end

  it "requires authentication for every write and edit form" do
    get new_post_path
    expect(response).to redirect_to(new_user_session_path)
    get edit_post_path(post_record)
    expect(response).to redirect_to(new_user_session_path)
    post posts_path, params: { post: { title: "Hacked photo" } }
    expect(response).to redirect_to(new_user_session_path)
    patch post_path(post_record), params: { post: { title: "Hacked photo" } }
    expect(response).to redirect_to(new_user_session_path)
    delete post_path(post_record)
    expect(response).to redirect_to(new_user_session_path)
    expect(post_record.reload.title).to eq("A mountain sunset")
  end

  it "forbids editing, updating or deleting another user's post" do
    sign_in create(:user)
    get edit_post_path(post_record)
    expect(response).to have_http_status(:forbidden)
    patch post_path(post_record), params: { post: { title: "Hacked photo" } }
    expect(response).to have_http_status(:forbidden)
    expect { delete post_path(post_record) }.not_to change(Post, :count)
    expect(response).to have_http_status(:forbidden)
    expect(post_record.reload.title).to eq("A mountain sunset")
  end

  it "assigns ownership from the session and ignores arbitrary user_id" do
    sign_in owner
    other = create(:user)
    expect {
      post posts_path, params: { post: { title: "A valid photo", photo: upload, user_id: other.id } }
    }.to change(Post, :count).by(1)
    expect(Post.last.user).to eq(owner)
    patch post_path(post_record), params: { post: { title: "Updated photo", user_id: other.id } }
    expect(response).to have_http_status(:see_other)
    expect(post_record.reload.user).to eq(owner)
    expect(post_record.title).to eq("Updated photo")
  end

  it "keeps the photo on an invalid update and returns validation errors" do
    sign_in owner
    blob = post_record.photo.blob
    patch post_path(post_record), params: { post: { title: "x" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(post_record.reload.photo.blob).to eq(blob)
  end

  it "allows the owner to delete and purges the stored file" do
    sign_in owner
    blob = post_record.photo.blob
    perform_enqueued_jobs do
      expect { delete post_path(post_record) }.to change(Post, :count).by(-1)
    end
    expect(response).to redirect_to(posts_path)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
    expect(blob.service.exist?(blob.key)).to be(false)
  end

  it "rejects attaching arbitrary signed blobs" do
    sign_in owner
    patch post_path(post_record), params: { post: { photo: post_record.photo.blob.signed_id } }
    expect(response).to have_http_status(:bad_request)
  end

  it "escapes stored HTML in public views" do
    post_record.update!(title: "<script>alert(1)</script>")
    get post_path(post_record)
    expect(response.body).to include("&lt;script&gt;")
    expect(response.body).not_to include("<script>alert(1)</script>")
  end
  it "serves a generated image through the public Active Storage routes" do
    get rails_representation_path(post_record.photo.variant(:medium))
    follow_redirect! while response.redirect?
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/jpeg")
    expect(response.body.bytesize).to be_positive
  end
end
