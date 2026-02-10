# frozen_string_literal: true

class ThrowingFormatter
  def call(_data)
    raise "bogus"
  end
end

RSpec.describe Heavylog do
  let(:buffer) { StringIO.new }
  let(:logger) { ActiveSupport::Logger.new(buffer) }
  let(:heavylog_config) do
    Heavylog::OrderedOptions.new.tap { |config|
      config.enabled = true
      config.message_limit = 1024 * 1024 * 50
      config.formatter = Heavylog::Formatters::Json.new
      config.custom_payload do |controller|
        {
          hostname: controller.request.host,
        }
      end
    }
  end

  let(:app) { Rails.application }
  let(:request) { Rack::MockRequest.new(app) }

  before :each do
    app.config.heavylog = heavylog_config
    Heavylog.setup_custom_payload
    Heavylog.logger = logger
    Heavylog.formatter = heavylog_config.formatter
  end

  it "has a version number" do
    expect(Heavylog::VERSION).not_to be nil
  end

  it "filters ansi from messages" do
    message = "\u001b[1m\u001b[35m (0.8ms)\u001b[0m  \u001b[1m\u001b[35mCOMMIT\u001b[0m"

    Heavylog.log(nil, message)

    expect(RequestStore.store[:heavylog_buffer].string).to eq(" (0.8ms)  COMMIT\n")
  end

  it "only tries to filter ansi from messages when possible" do
    message = ["\u001b[1m\u001b[35m (0.8ms)\u001b[0m  \u001b[1m\u001b[35mCOMMIT\u001b[0m"]

    Heavylog.log(nil, message)

    expect(RequestStore.store[:heavylog_buffer].string).to eq(" (0.8ms)  COMMIT\n")
  end

  it "fetches message from block if block given" do
    Heavylog.log(nil) do
      "block message"
    end

    expect(RequestStore.store[:heavylog_buffer].string).to eq("block message\n")
  end

  it "fetches message from progname if message is nil" do
    Heavylog.log(nil, nil, "progname")

    expect(RequestStore.store[:heavylog_buffer].string).to eq("progname\n")
  end

  it "logs the custom payload" do
    request.get("/test")

    line = JSON.parse(buffer.string)

    expect(line["hostname"]).to eq("example.org")
  end

  it "doesn't bubble up exceptions in formatters" do
    exception = nil

    Heavylog.formatter = ThrowingFormatter.new
    app.config.heavylog.error_handler = ->(e) { exception = e }

    expect { request.get("/test") }.to_not raise_error
    expect(exception.message).to include("bogus")
  end
end
