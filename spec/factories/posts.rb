FactoryBot.define do
  factory :post do
    title { "A mountain sunset" }
    description { "An afternoon in the mountains" }
    association :user
    photo { Rack::Test::UploadedFile.new(Rails.root.join("spec/factories/photobook.jpg"), "image/jpeg") }
    factory :post_with_longdescription do
      description { "a" * 65 }
    end
  end
end
