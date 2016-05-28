require 'rails_helper'

RSpec.feature "Authentications", type: :feature do

  scenario "failed with invalid credentials" do
    visit new_user_session_path

    fill_in 'Email', :with => 'email@example.com'
    fill_in 'Password', :with => 'password'
    click_button 'Log in'

    expect(page).to have_text 'Invalid Email or password'
  end

  scenario "with valid credentials" do
    user = create(:user)

    visit new_user_session_path

    fill_in 'Email', :with => user.email
    fill_in 'Password', :with => user.password
    click_button 'Log in'

    expect(page).to have_text 'Signed in successfully'
  
    visit new_post_path

    fill_in 'Title', :with => 'Titulo del Post'
    fill_in 'Description', :with => 'Esto es una prueba'
    attach_file("Photo","#{Rails.root}/spec/factories/photobook.jpg") 
    click_button 'Create Post'

    expect(page).to have_text 'Post was successfully created'
  end

end
