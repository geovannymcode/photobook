FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "photographer#{n}" }
    firstname { "Jon" }
    lastname { "Snow" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
