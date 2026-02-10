# frozen_string_literal: true

module Heavylog
  class ProxyLogger < ::Logger
    def initialize
      super(nil)
    end

    def add(severity, message=nil, progname=nil, &)
      Heavylog.log(severity, message, progname, &)
    end

    def loggable?
      true
    end
  end
end
