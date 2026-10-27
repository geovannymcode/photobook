require "rails_helper"

RSpec.describe "Post photographs", type: :model do
  it "rejects a non-image masquerading as a JPEG" do
    file = Tempfile.new([ "fake", ".jpg" ])
    file.write("<script>alert(1)</script>")
    file.rewind
    post = build(:post, photo: Rack::Test::UploadedFile.new(file.path, "image/jpeg"))
    expect(post).not_to be_valid
    expect(post.errors[:photo]).to be_present
  ensure
    file.close!
  end

  it "rejects an oversized image" do
    post = build(:post)
    post.photo.blob.byte_size = Post::MAX_PHOTO_SIZE + 1
    expect(post).not_to be_valid
    expect(post.errors[:photo]).to include("must be at most 10 MB")
  end

  it "rejects SVG" do
    file = Tempfile.new([ "vector", ".svg" ])
    file.write('<svg xmlns="http://www.w3.org/2000/svg"/>')
    file.rewind
    expect(build(:post, photo: Rack::Test::UploadedFile.new(file.path, "image/svg+xml"))).not_to be_valid
  ensure
    file.close!
  end

  it "generates all variants without stretching or upscaling" do
    post = create(:post)
    original = Vips::Image.new_from_file(Rails.root.join("spec/factories/photobook.jpg").to_s)
    { large: 600, medium: 300, thumb: 100 }.each do |name, bound|
      variant = post.photo.variant(name).processed
      image = Vips::Image.new_from_buffer(variant.download, "")
      expect(image.width).to be <= [ bound, original.width ].min
      expect(image.height).to be <= [ bound, original.height ].min
      expect(image.width.to_f / image.height).to be_within(0.03).of(original.width.to_f / original.height)
    end
  end
end
