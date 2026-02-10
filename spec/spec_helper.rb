# frozen_string_literal: true

require "bundler/setup"
require "action_controller/railtie"
require "action_view/railtie"
Bundler.require(:default, :test)

require "app/application"
require "heavylog"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    Rails.application.config.heavylog = Heavylog::OrderedOptions.new.tap { |heavylog_config|
      heavylog_config.enabled = true
      heavylog_config.message_limit = 1024 * 1024 * 50
      heavylog_config.formatter = Heavylog::Formatters::Json.new
    }
    Heavylog.setup(Rails.application)
  end

  config.before(:each) do
    RequestStore.clear!
    RequestStore.store[:heavylog_request_id] = SecureRandom.hex
  end
end
