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

    # Auto-discover and load recipes from a directory
    def discover_recipes(path = nil)
      path ||= File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "reweave", "recipes")
      return unless Dir.exist?(path)

      Dir.glob(File.join(path, "**", "*.rb")).each do |file|
        require file
      end
    end
  end

  REGISTRY = RecipeRegistry.new
end
