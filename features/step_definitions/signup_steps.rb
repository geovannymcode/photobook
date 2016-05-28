Given(/^I am on the "([^"]*)" page$/) do |page|
  visit("users/"+page)
end

Given(/^I fill in "([^"]*)" with "([^"]*)"$/) do |field, value|
  fill_in("user_"+field, :with => value)
end

When(/^I press "([^"]*)"$/) do |button|
  click_button(button)
end

Then(/^page should have notice message "([^"]*)"$/) do |message|
  expect(page).to have_content(message)
end