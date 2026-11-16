# frozen_string_literal: true

require_relative "recipe"

module Reweave
  class RecipeRegistry
    def initialize
      @recipes = {}
    end

    def register(recipe_class, name: nil)
      name ||= recipe_class.name
      @recipes[name] = recipe_class
    end

    def get(name)
      @recipes[name] || @recipes.values.find { |r| r.name.split("::").last == name }
    end

    def all
      @recipes.values
    end

    def names
      @recipes.keys
    end

    def find_by_display_name(display_name)
      @recipes.values.find { |r| r.display_name == display_name }
    end
  end

  REGISTRY = RecipeRegistry.new
end
