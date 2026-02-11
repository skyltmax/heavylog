# frozen_string_literal: true

module Heavylog
  module Adapters
    autoload :KarafkaConsumer,        "heavylog/adapters/karafka_consumer"
    autoload :SidekiqLogger,          "heavylog/adapters/sidekiq_logger"
    autoload :SidekiqExceptionHandler, "heavylog/adapters/sidekiq_exception_handler"
  end
end
