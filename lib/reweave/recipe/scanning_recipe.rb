# frozen_string_literal: true

require_relative "recipe"

module Reweave
  # Scanning recipe base class
  class ScanningRecipe < Recipe
    def scanning_recipe?
      true
    end

    def initial_accumulator
      {}
    end

    def scan(source_file, accumulator, context)
      # Override in subclass
    end

    def generate(accumulator, project)
      # Override to generate files from accumulated data
      []
    end

    def get_visitor(accumulator, context)
      # Override to return a visitor that uses accumulated data
      nil
    end
  end
end
