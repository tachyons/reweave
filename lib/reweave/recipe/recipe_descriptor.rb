# frozen_string_literal: true

module Reweave
  class RecipeDescriptor
    attr_reader :recipe_class, :display_name, :description, :options

    def initialize(recipe)
      @recipe_class = recipe.class
      @display_name = recipe.display_name
      @description = recipe.description
      @options = recipe.class.options.transform_values do |opt|
        {
          type: opt.type,
          required: opt.required?,
          default: opt.default,
          description: opt.description
        }
      end
    end

    def to_h
      {
        name: @recipe_class.name,
        display_name: @display_name,
        description: @description,
        options: @options
      }
    end

    def to_yaml
      require "yaml"
      to_h.to_yaml
    end
  end
end
