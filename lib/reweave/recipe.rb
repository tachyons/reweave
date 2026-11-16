# frozen_string_literal: true

require_relative "recipe/recipe"
require_relative "recipe/recipe_option"
require_relative "recipe/recipe_descriptor"
require_relative "recipe/validation_error"
require_relative "recipe/composite_recipe"
require_relative "recipe/scanning_recipe"
require_relative "recipe/recipe_registry"

# Recipe is a class, not a module - the submodules are accessed via Reweave::Recipe::<ClassName>
