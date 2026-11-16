# frozen_string_literal: true

require "yaml"

module Reweave
  module Config
    class ValidationError < StandardError; end

    class << self
      def load(file_path)
        raise ValidationError, "Config file not found: #{file_path}" unless File.exist?(file_path)

        config = YAML.safe_load_file(file_path, permitted_classes: [Symbol], aliases: true)
        validate!(config)
        config
      rescue Psych::SyntaxError => e
        raise ValidationError, "Invalid YAML: #{e.message}"
      end

      def validate!(config)
        unless config.is_a?(Hash)
          raise ValidationError, "Config must be a Hash"
        end

        validate_recipes(config["recipes"]) if config["recipes"]
        validate_recipe_list(config["recipe_list"]) if config["recipe_list"]
        validate_single_recipe(config) if config["name"]
      end

      def validate_single_recipe(config)
        name = config["name"]
        unless Reweave::REGISTRY.get(name)
          raise ValidationError, "Unknown recipe: '#{name}' (not registered)"
        end

        if config["options"]
          validate_options(name, config["options"])
        end
      end

      def validate_recipes(recipes)
        unless recipes.is_a?(Array)
          raise ValidationError, "'recipes' must be an Array"
        end

        recipes.each_with_index do |recipe, index|
          validate_recipe(recipe, index)
        end
      end

      def validate_recipe(recipe, index)
        unless recipe.is_a?(Hash)
          raise ValidationError, "Recipe at index #{index} must be a Hash"
        end

        unless recipe["name"]
          raise ValidationError, "Recipe at index #{index} must have a 'name'"
        end

        name = recipe["name"]
        unless Reweave::REGISTRY.get(name)
          raise ValidationError, "Unknown recipe: '#{name}' (not registered)"
        end

        if recipe["options"]
          validate_options(recipe["name"], recipe["options"])
        end
      end

      def validate_options(recipe_name, options)
        unless options.is_a?(Hash)
          raise ValidationError, "Options for '#{recipe_name}' must be a Hash"
        end

        recipe_class = Reweave::REGISTRY.get(recipe_name)
        return unless recipe_class

        known_options = recipe_class.options.keys
        unknown = options.keys - known_options.map(&:to_s)
        unless unknown.empty?
          raise ValidationError, "Unknown options for '#{recipe_name}': #{unknown.join(", ")}"
        end
      end

      def validate_recipe_list(recipe_list)
        unless recipe_list.is_a?(Array)
          raise ValidationError, "'recipe_list' must be an Array"
        end

        recipe_list.each_with_index do |recipe, index|
          validate_recipe(recipe, index)
        end
      end

      def build_recipe(config)
        Reweave::REGISTRY.discover_recipes

        if config["recipe_list"]
          # Composite recipe from list
          recipes = config["recipe_list"].map { |r| build_recipe(r) }
          Reweave::CompositeRecipe.new(recipes)
        elsif config["recipes"]
          # Multiple recipes as composite
          recipes = config["recipes"].map { |r| build_recipe(r) }
          Reweave::CompositeRecipe.new(recipes)
        elsif config["name"]
          # Single recipe
          recipe_class = Reweave::REGISTRY.get(config["name"])
          raise ValidationError, "Unknown recipe: '#{config["name"]}'" unless recipe_class

          options = config["options"]&.transform_keys(&:to_sym) || {}
          recipe_class.new(**options)
        else
          raise ValidationError, "Config must have 'name', 'recipes', or 'recipe_list'"
        end
      end
    end
  end
end
