# frozen_string_literal: true

require "sidekiq"
require "sidekiq/job_logger"

RSpec.describe Heavylog::Adapters::SidekiqExceptionHandler do
  let(:buffer) { StringIO.new }
  let(:logger) { ActiveSupport::Logger.new(buffer) }
  let(:handler) { described_class.new }

  before(:each) do
    RequestStore.clear!
    Heavylog.logger = logger

    # Simulate a job already in progress
    Heavylog.log_job("job_jid_123", "SidekiqLogger", "FailingWorker", [42])
  end

  it "logs exception with non-empty context" do
    exception = RuntimeError.new("something went wrong")
    exception.set_backtrace(["app/workers/failing_worker.rb:10:in `perform'", "lib/heavylog.rb:5:in `call'"])
    context = { queue: "critical", job: "FailingWorker" }

    handler.call(exception, context)

    output = JSON.parse(buffer.string)

    expect(output["messages"]).to include("queue")
    expect(output["messages"]).to include("FailingWorker")
    expect(output["messages"]).to include("RuntimeError: something went wrong")
    expect(output["messages"]).to include("app/workers/failing_worker.rb:10")
  end

  it "skips context line when context is empty" do
    exception = RuntimeError.new("oops")
    exception.set_backtrace(["worker.rb:1:in `perform'"])

    handler.call(exception, {})

    output = JSON.parse(buffer.string)

    expect(output["messages"]).to include("RuntimeError: oops")
    expect(output["messages"]).to include("worker.rb:1")
    # The context should not appear since it was empty
    expect(output["messages"]).not_to include("{}")
  end

  it "handles exception with nil backtrace" do
    exception = Exception.new("no trace")
    # backtrace is nil before the exception is raised

    expect {
      handler.call(exception, {})
    }.not_to raise_error

    output = JSON.parse(buffer.string)
    expect(output["messages"]).to include("Exception: no trace")
  end

  it "clears RequestStore after handling" do
    exception = RuntimeError.new("fail")
    exception.set_backtrace(["worker.rb:1"])

    handler.call(exception, {})

    expect(RequestStore.store[:heavylog_request_id]).to be_nil
    expect(RequestStore.store[:heavylog_buffer]).to be_nil
  end

  it "preserves job metadata in the flushed output" do
    exception = RuntimeError.new("fail")
    exception.set_backtrace(["worker.rb:1"])

    handler.call(exception, { queue: "default" })

    output = JSON.parse(buffer.string)

    expect(output["request_id"]).to eq("job_jid_123")
    expect(output["controller"]).to eq("SidekiqLogger")
    expect(output["action"]).to eq("FailingWorker")
  end
end
