# frozen_string_literal: true

module Heavylog
  module RequestLogger
    def add(severity, message=nil, progname=nil, &)
      super
      Heavylog.log(severity, message, progname, &)
    end
  end
end
