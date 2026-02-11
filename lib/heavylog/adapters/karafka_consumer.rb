# frozen_string_literal: true

module Heavylog
  module Adapters
    class KarafkaConsumer < ::Karafka::BaseConsumer
      # Runs inside the Rails reloader wrap, any earlier would run outside the thread the consume method runs in.
      def on_consume
        args = "topic=#{topic.name} partition=#{partition} messages=#{messages.count}"
        Heavylog.log_job(SecureRandom.uuid, "KarafkaLogger", self.class.name, args)
        heavylog_before_consume
        super
      end

      def heavylog_before_consume
        # This is a hook for the users to access heavylog metadata before the consumer runs.
      end

      def wrap(action)
        yield
      ensure
        Heavylog.finish_job if action == :consume
      end
    end
  end
end
