FactoryGirl.define do
  factory :post do
    title { Faker::Name.name }
    photo { Rack::Test::UploadedFile.new("#{Rails.root}/spec/factories/photobook.jpg", "image/jpeg") } # File Upload
    description { Faker::Lorem.sentence(3, true, 4) }
    user_id { Faker::Number.number(4) }

    factory :post_with_longdescription do
      description { Faker::Lorem.paragraph }
    end
  end
end