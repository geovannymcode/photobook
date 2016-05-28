require 'rails_helper'

RSpec.describe User, type: :model do

  describe "creation" do

    it "has a valid class" do
      expect(described_class).to_not be_nil
    end

    context "with invalid attributes" do

      it "should not be valid" do
        @user = build(:user, username: "", firstname: "", lastname: "", email: "" )
        expect(@user.save).to be false
      end
     
      it "should not be valid without username" do
        @user = build(:user, username: "")
        expect(@user.save).to be false
      end
      
      it "should not be valid with short firstname" do
        @user = build(:user, firstname: "V")
        expect(@user.save).to be false
      end
      
      it "should not be valid with short lastname" do
        @user = build(:user, lastname: "L")
        expect(@user.save).to be false
      end

    end

    context "with valid attributes" do

      it "should be valid" do
        @user = build(:user)
        expect(@user.save).to be true
      end

    end

  end

end
