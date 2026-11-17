# frozen_string_literal: true

require_relative "reweave/version"
require_relative "reweave/parser"
require_relative "reweave/source"
require_relative "reweave/visitor"
require_relative "reweave/editing"
require_relative "reweave/recipe"
require_relative "reweave/recipe/composite_recipe"
require_relative "reweave/recipe/scanning_recipe"
require_relative "reweave/execution"
require_relative "reweave/results"
require_relative "reweave/discovery/file_discoverer"
require_relative "reweave/config"
require_relative "reweave/skills"
require_relative "reweave/recipes/security"
require_relative "reweave/recipes/bundler/gemfile_upgrade"
require_relative "reweave/recipes/static_analysis/rubocop_mapping"
require_relative "reweave/recipes/static_analysis/auto_fix"
require_relative "reweave/recipes/static_analysis/custom_cops"

module Reweave
  class Error < StandardError; end
  class ParseError < Error; end
  class EditError < Error; end
  class RecipeError < Error; end

  def self.run(recipe, path: ".", source: nil, dry_run: true, max_cycles: 10, patterns: nil, exclude: nil)
    Execution::Engine.new(dry_run: dry_run, max_cycles: max_cycles).run(recipe, path: path, source: source, patterns: patterns, exclude: exclude)
  end

  def self.parse(source, path: nil)
    Parser.parse(source, path: path)
  end
end
