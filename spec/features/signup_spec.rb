require "rails_helper"

RSpec.feature "Home and signup", type: :feature do
  scenario "public home links to a new post" do
    visit root_path
    expect(page).to have_link("New Post", href: new_post_path)
  end

  scenario "registering a complete user" do
    visit new_user_registration_path
    fill_in "Username", with: "whitewolf"
    fill_in "Firstname", with: "Jon"
    fill_in "Lastname", with: "Snow"
    fill_in "Location", with: "The wall"
    fill_in "Email", with: "jon.snow@example.com"
    fill_in "Password", with: "password123", exact: true
    fill_in "Password confirmation", with: "password123"
    click_button "Sign up"
    expect(page).to have_content("Welcome! You have signed up successfully.")
  end
end
