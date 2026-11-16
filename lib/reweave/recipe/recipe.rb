# frozen_string_literal: true

require_relative "recipe_option"
require_relative "recipe_descriptor"
require_relative "validation_error"

module Reweave
  class Recipe
    class << self
      def display_name(name = nil)
        if name
          @display_name = name
        else
          @display_name ||= name_from_class
        end
      end

      def description(text = nil)
        if text
          @description = text
        else
          @description
        end
      end

      def option(name, type:, required: false, default: nil, description: nil, &block)
        @options ||= {}
        @options[name] = RecipeOption.new(name, type: type, required: required, default: default, description: description, &block)
      end

      def options
        @options ||= {}
        inherited_options = superclass.respond_to?(:options) ? superclass.options : {}
        inherited_options.merge(@options)
      end

      def name_from_class
        name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@options, options.dup) if @options
        super
      end
    end

    attr_reader :config, :options

    def initialize(**kwargs)
      @config = self.class.options.transform_values { |opt| opt.default }
      @options = kwargs

      validate_options!
      @config.merge!(@options)
      freeze
    end

    def display_name
      self.class.display_name
    end

    def description
      self.class.description
    end

    def descriptor
      RecipeDescriptor.new(self)
    end

    def recipe_list
      []
    end

    def get_visitor(context)
      nil
    end

    def scanning_recipe?
      false
    end

    def validate
      []
    end

    def ==(other)
      other.is_a?(self.class) && other.config == @config
    end
    alias_method :eql?, :==

    def hash
      [self.class, @config].hash
    end

    private

    def validate_options!
      self.class.options.each do |name, option|
        value = @options[name]
        if option.required? && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
          raise ValidationError, "Required option '#{name}' not provided for #{self.class.display_name}"
        end
        if value && !option.valid?(value)
          raise ValidationError, "Invalid value for option '#{name}': #{option.validate_message(value)}"
        end
      end

      unknown = @options.keys - self.class.options.keys
      unless unknown.empty?
        raise ValidationError, "Unknown options: #{unknown.join(", ")}"
      end
    end
  end
end
