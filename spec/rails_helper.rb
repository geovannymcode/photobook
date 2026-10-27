ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("Refusing to test production") if Rails.env.production?
require "spec_helper"
require "rspec/rails"
require "capybara/rspec"
ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
end
