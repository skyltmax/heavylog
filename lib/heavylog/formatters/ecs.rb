# frozen_string_literal: true

require "json"

module Heavylog
  module Formatters
    class ECS
      # mapping from heavylog standard keys to ECS https://www.elastic.co/guide/en/ecs/current/ecs-reference.html
      ECS_MAP = {
        "request_start"      => "@timestamp",
        "messages"           => "message",
        "request_id"         => "http.request.id",
        "method"             => "http.request.method",
        "referrer"           => "http.request.referrer",
        "format"             => "http.response.format",
        "status"             => "http.response.status_code",
        "location"           => "http.response.location",
        "ip"                 => "source.address",
        "host"               => "url.domain",
        "path"               => "url.original",
        "user_agent"         => "user_agent.original",
        "controller"         => "heavylog.controller",
        "action"             => "heavylog.action",
        "unpermitted_params" => "heavylog.unpermitted_params",
        "args"               => "heavylog.args",
        "duration"           => "heavylog.duration",
        "view_runtime"       => "heavylog.view_runtime",
        "db_runtime"         => "heavylog.db_runtime",
      }.freeze

      def call(data)
        ECS_MAP.each do |original, correct|
          dig_set(data, correct.split("."), data.delete(original)) if data.key?(original)
        end

        dig_set(data, %w[event module], "heavylog")
        dig_set(data, %w[event category], "web")

        unless data.dig("event", "dataset")
          value = case data.dig("heavylog", "controller")
                  when "SidekiqLogger"
                    "heavylog.sidekiq"
                  when "KarafkaLogger"
                    "heavylog.karafka"
                  else
                    "heavylog.rails"
                  end

          dig_set(data, %w[event dataset], value)
        end

        if (code = data.dig("http", "response", "status_code"))
          dig_set(data, %w[event outcome], (200..399).cover?(code) ? "success" : "failure")
        end

        dig_set(data, %w[source ip], data.dig("source", "address")) unless data.dig("source", "ip")
        dig_set(data, %w[url path], data.dig("url", "original")) unless data.dig("url", "path")

        ::JSON.dump(data)
      end

      private

      def dig_set(obj, keys, value)
        key = keys.first
        if keys.length == 1
          obj[key] = value
        else
          obj[key] = {} unless obj[key]
          dig_set(obj[key], keys.slice(1..-1), value)
        end
      end
    end
  end
end
