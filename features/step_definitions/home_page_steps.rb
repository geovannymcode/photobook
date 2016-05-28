Given ("Nothing") do

end

When(/^I am on the homepage$/) do
  visit root_path
end

Then(/^I should see the "(.*?)" post$/) do |title|
  expect(page).to have_content(title)
end