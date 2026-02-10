# frozen_string_literal: true

RSpec.describe Heavylog::Formatters::Raw do
  let(:buffer) { StringIO.new }
  let(:logger) { ActiveSupport::Logger.new(buffer) }
  let(:heavylog_config) do
    Heavylog::OrderedOptions.new.tap { |config|
      config.enabled = true
      config.message_limit = 1024 * 1024 * 50
      config.formatter = subject
    }
  end

  subject { Heavylog::Formatters::Raw.new }
  let(:app) { Rails.application }
  let(:request) { Rack::MockRequest.new(app) }

  before :each do
    app.config.heavylog = heavylog_config
    Heavylog.set_options
    Heavylog.logger = logger
  end

  it "logs the request as raw" do
    request.get("/test")

    line = buffer.string

    expect(line).to include("logger from action")
    expect(line).to include("\"view_runtime\" =>")
  end
end
