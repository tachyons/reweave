# frozen_string_literal: true

require_relative "recipe"

module Reweave
  class CompositeRecipe < Recipe
    def initialize(recipes = [], **kwargs)
      @recipes = recipes
      super(**kwargs)
    end

    def recipe_list
      @recipes
    end

    attr_reader :recipes

    def ==(other)
      super && other.recipes == @recipes
    end

    def hash
      [super, @recipes].hash
    end
  end
end
