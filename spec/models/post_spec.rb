require 'rails_helper'

RSpec.describe Post, type: :model do

  describe "creation" do

    it "has a valid class" do
      expect(described_class).to_not be_nil
    end

    context "with invalid attributes" do

      it "should not be valid" do
        @post = build(:post, title: "", description: "")
        expect(@post.save).to be false
      end

      it "should not be valid without title" do
        @post = build(:post, title: "")
        expect(@post.save).to be false
      end

      it "should not be valid without user_id" do
        @post = build(:post, user_id: nil)
        expect(@post.save).to be false
      end

      it "should not be valid with short title" do
        @post = build(:post, title: "H")
        expect(@post.save).to be false
      end

      it "should not be valid with long description" do
        @post = build(:post_with_longdescription)
        expect(@post.save).to be false
      end
      
      it "should not be valid without photo" do
         @post = build(:post, photo: nil)
         expect(@post.save).to be false
      end

    end

    context "with valid attributes" do

      it "should be valid" do
        @post = build(:post)
        expect(@post.save).to be true
      end

    end

  end

end