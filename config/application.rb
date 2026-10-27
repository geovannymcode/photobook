require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module Workspace
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.active_storage.variant_processor = :vips
    config.active_job.queue_adapter = :inline
    config.generators.system_tests = nil
  end
end
