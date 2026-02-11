# frozen_string_literal: true

require "sidekiq"
require "sidekiq/job_logger"

RSpec.describe Heavylog::Adapters::SidekiqLogger do
  let(:buffer) { StringIO.new }
  let(:logger) { ActiveSupport::Logger.new(buffer) }

  let(:sidekiq_config) do
    Sidekiq::Config.new.tap do |config|
      config[:job_logger] = described_class
      # Redirect Sidekiq's own logger so its "start"/"done" messages
      # don't pollute the Heavylog assertion buffer
      config.logger = ::Logger.new(StringIO.new)
    end
  end

  let(:job_logger) { described_class.new(sidekiq_config) }

  let(:item) do
    {
      "class"       => "HardWorker",
      "args"        => [123, "invoice"],
      "retry"       => true,
      "queue"       => "default",
      "jid"         => "abc123def456",
      "created_at"  => Time.now.to_f,
      "enqueued_at" => Time.now.to_f,
    }
  end

  before(:each) do
    RequestStore.clear!
    Heavylog.logger = logger
  end

  it "logs a job end-to-end with correct metadata" do
    job_logger.call(item, "default") do
      Heavylog.log(:info, "processing invoice")
    end

    output = JSON.parse(buffer.string)

    expect(output["request_id"]).to eq("abc123def456")
    expect(output["controller"]).to eq("SidekiqLogger")
    expect(output["action"]).to eq("HardWorker")
    expect(output["args"]).to eq('[123, "invoice"]')
    expect(output["messages"]).to include("processing invoice")
  end

  it "clears RequestStore after the job completes" do
    job_logger.call(item, "default") {}

    expect(RequestStore.store[:heavylog_request_id]).to be_nil
    expect(RequestStore.store[:heavylog_buffer]).to be_nil
  end

  it "flushes logs and clears RequestStore even when the job raises" do
    expect {
      job_logger.call(item, "default") { raise "boom" }
    }.to raise_error(RuntimeError, "boom")

    output = JSON.parse(buffer.string)

    expect(output["request_id"]).to eq("abc123def456")
    expect(output["controller"]).to eq("SidekiqLogger")
    expect(output["action"]).to eq("HardWorker")

    expect(RequestStore.store[:heavylog_request_id]).to be_nil
  end

  it "handles multiple sequential jobs independently" do
    job_logger.call(item, "default") do
      Heavylog.log(:info, "first job")
    end

    second_item = item.merge("jid" => "second_jid_789", "class" => "EasyWorker")

    job_logger.call(second_item, "default") do
      Heavylog.log(:info, "second job")
    end

    lines = buffer.string.strip.split("\n")
    expect(lines.length).to eq(2)

    first_output = JSON.parse(lines[0])
    second_output = JSON.parse(lines[1])

    expect(first_output["request_id"]).to eq("abc123def456")
    expect(first_output["action"]).to eq("HardWorker")
    expect(first_output["messages"]).to include("first job")
    expect(first_output["messages"]).not_to include("second job")

    expect(second_output["request_id"]).to eq("second_jid_789")
    expect(second_output["action"]).to eq("EasyWorker")
    expect(second_output["messages"]).to include("second job")
    expect(second_output["messages"]).not_to include("first job")
  end

  it "captures the request start time" do
    job_logger.call(item, "default") {}

    output = JSON.parse(buffer.string)
    expect(output["request_start"]).not_to be_nil
    expect { Time.iso8601(output["request_start"]) }.not_to raise_error
  end

  it "sets ip to 127.0.0.1 for sidekiq jobs" do
    job_logger.call(item, "default") {}

    output = JSON.parse(buffer.string)
    expect(output["ip"]).to eq("127.0.0.1")
  end
end
