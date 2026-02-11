# frozen_string_literal: true

require "support/karafka_setup"

RSpec.describe Heavylog::Adapters::KarafkaConsumer do
  include Karafka::Testing::RSpec::Helpers

  let(:buffer) { StringIO.new }
  let(:logger) { ActiveSupport::Logger.new(buffer) }

  before(:each) do
    RequestStore.clear!
    Heavylog.logger = logger
  end

  context "with consume lifecycle" do
    subject(:consumer) { karafka.consumer_for(:test_topic) }

    before do
      karafka.produce("test payload")
    end

    it "logs a consumed job with correct metadata" do
      consumer.on_wrap(:consume) { consumer.on_consume }

      output = JSON.parse(buffer.string)

      expect(output["controller"]).to eq("KarafkaLogger")
      expect(output["action"]).to eq("TestKarafkaConsumer")
      expect(output["args"]).to include("topic=test_topic")
      expect(output["args"]).to include("partition=0")
      expect(output["args"]).to include("messages=1")
    end

    it "captures messages logged during consume" do
      consumer.on_wrap(:consume) { consumer.on_consume }

      output = JSON.parse(buffer.string)

      expect(output["messages"]).to include("consumed: test payload")
    end

    it "assigns a unique request_id" do
      consumer.on_wrap(:consume) { consumer.on_consume }

      output = JSON.parse(buffer.string)

      expect(output["request_id"]).not_to be_nil
      expect(output["request_id"].length).to be > 0
    end

    it "captures the request start time as ISO8601" do
      consumer.on_wrap(:consume) { consumer.on_consume }

      output = JSON.parse(buffer.string)

      expect(output["request_start"]).not_to be_nil
      expect { Time.iso8601(output["request_start"]) }.not_to raise_error
    end

    it "clears RequestStore after consume" do
      consumer.on_wrap(:consume) { consumer.on_consume }

      expect(RequestStore.store[:heavylog_request_id]).to be_nil
      expect(RequestStore.store[:heavylog_buffer]).to be_nil
    end

    it "handles multiple messages in a batch" do
      karafka.produce("second payload")

      consumer.on_wrap(:consume) { consumer.on_consume }

      output = JSON.parse(buffer.string)

      expect(output["args"]).to include("messages=2")
      expect(output["messages"]).to include("consumed: test payload")
      expect(output["messages"]).to include("consumed: second payload")
    end
  end

  context "with wrap lifecycle" do
    subject(:consumer) { karafka.consumer_for(:test_topic) }

    before do
      karafka.produce("payload")
    end

    it "does not flush on non-consume actions" do
      # Manually set up log_job to simulate a job in progress
      Heavylog.log_job(SecureRandom.uuid, "KarafkaLogger", "TestKarafkaConsumer", "test")

      consumer.on_wrap(:revoked) {}

      # wrap with :revoked should not call finish_job, so buffer should still be empty
      # (no flush occurred — the log_job data is still in RequestStore, not flushed to logger)
      expect(buffer.string).to eq("")
    end

    it "flushes and clears RequestStore even when consume raises" do
      error_consumer_class = Class.new(Heavylog::Adapters::KarafkaConsumer) do
        def consume
          Heavylog.log(:info, "before error")
          raise "consumer boom"
        end
      end

      # We need to test with a consumer that raises during consume.
      # Since on_consume rescues StandardError via the strategy, we test that
      # wrap's ensure still runs finish_job.
      Heavylog.log_job(SecureRandom.uuid, "KarafkaLogger", "ErrorConsumer", "args")
      Heavylog.log(:info, "error test message")

      # Simulate wrap(:consume) calling finish_job in ensure
      consumer.on_wrap(:consume) { raise "boom" }

      output = JSON.parse(buffer.string)
      expect(output["messages"]).to include("error test message")
      expect(RequestStore.store[:heavylog_request_id]).to be_nil
    end
  end

  context "with heavylog_before_consume hook" do
    subject(:consumer) { karafka.consumer_for(:test_topic) }

    before do
      karafka.produce("hook test")
    end

    it "provides a heavylog_before_consume hook that runs after log_job setup" do
      hook_request_id = nil

      consumer.define_singleton_method(:heavylog_before_consume) do
        hook_request_id = RequestStore.store[:heavylog_request_id]
        Heavylog.log(:info, "hook ran")
      end

      consumer.on_wrap(:consume) { consumer.on_consume }

      # The hook should have seen the request_id set by log_job
      expect(hook_request_id).not_to be_nil

      output = JSON.parse(buffer.string)
      expect(output["messages"]).to include("hook ran")
    end
  end
end
