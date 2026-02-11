# frozen_string_literal: true

require "karafka"
require "karafka/testing/rspec/helpers"

# A test consumer that inherits from Heavylog's KarafkaConsumer adapter
# so we can exercise the real Karafka consumer lifecycle with Heavylog integration.
class TestKarafkaConsumer < Heavylog::Adapters::KarafkaConsumer
  def consume
    messages.each do |message|
      Heavylog.log(:info, "consumed: #{message.raw_payload}")
    end
  end
end

# Minimal Karafka app configuration for testing.
# No Kafka broker connection is needed — karafka-testing stubs the client.
Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "localhost:9092" }
  config.client_id = "heavylog_test"
end

Karafka::App.routes.draw do
  topic :test_topic do
    consumer TestKarafkaConsumer
  end
end
