# frozen_string_literal: true

module Reweave
  class RecipeOption
    attr_reader :name, :type, :required, :default, :description, :validator

    def initialize(name, type:, required: false, default: nil, description: nil, &block)
      @name = name
      @type = type
      @required = required
      @default = default
      @description = description
      @validator = block
    end

    def required?
      @required
    end

    def valid?(value)
      return false unless type_match?(value)
      return true unless @validator
      @validator.call(value)
    end

    def validate_message(value)
      unless type_match?(value)
        return "expected #{@type}, got #{value.class}"
      end
      "validation failed" if @validator && !@validator.call(value)
    end

    private

    def type_match?(value)
      case @type
      when Class, Module
        value.is_a?(@type)
      when Array
        value.is_a?(Array) && value.all? { |v| type_match?(v) }
      else
        true
      end
    end
  end
end
