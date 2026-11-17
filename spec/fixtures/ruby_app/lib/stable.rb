# frozen_string_literal: true

# Plain code fixture: every recipe must run over it without crashing.
module Stable
  class Widget
    def initialize(name)
      @name = name
    end

    def describe
      if @name.nil?
        "anonymous"
      else
        @name.to_s
      end
    end
  end
end
