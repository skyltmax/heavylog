# frozen_string_literal: true

require "sidekiq"
require "sidekiq/job_logger"

RSpec.describe "Heavylog.attach_to_sidekiq" do
  it "does not configure sidekiq when log_sidekiq is falsy" do
    expect(Sidekiq).not_to receive(:configure_server)

    original = Heavylog.config.log_sidekiq
    Heavylog.config.log_sidekiq = false
    Heavylog.attach_to_sidekiq
    Heavylog.config.log_sidekiq = original
  end

  it "sets SidekiqLogger as job_logger and adds SidekiqExceptionHandler" do
    sidekiq_config = Sidekiq::Config.new

    original = Heavylog.config.log_sidekiq
    Heavylog.config.log_sidekiq = true

    allow(Sidekiq).to receive(:configure_server).and_yield(sidekiq_config)

    Heavylog.attach_to_sidekiq

    expect(sidekiq_config[:job_logger]).to eq(Heavylog::Adapters::SidekiqLogger)
    expect(sidekiq_config.error_handlers).to include(
      an_instance_of(Heavylog::Adapters::SidekiqExceptionHandler)
    )

    Heavylog.config.log_sidekiq = original
  end
end
