# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module StaticAnalysis
      # Integrate custom RuboCop cops with Reweave recipes
      class CustomCops < Reweave::Recipe::DeclarativeRecipe
        display_name "Custom Cop Integration"
        description "Integrate custom RuboCop cops with Reweave recipes"

        option :cop_config_path, type: String, default: ".rubocop.yml", description: "Path to RuboCop config file"
        option :custom_cop_dirs, type: Array, default: [], description: "Directories containing custom cops"

        # This recipe doesn't directly transform code - it provides a framework
        # for integrating custom RuboCop cops with Reweave recipes
        #
        # Usage:
        # 1. Define custom cops in your .rubocop.yml or custom cop files
        # 2. Run rubocop to get violations
        # 3. Map cop names to Reweave recipes using this integration
        # 4. Run Reweave recipes to auto-fix violations

        def get_visitor(context)
          CustomCopsVisitor.new(context, config)
        end
      end

      class CustomCopsVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # Check if this call matches any custom cop violation
          check_custom_cops(node)
          super
        end

        private

        def check_custom_cops(node)
          # This would be populated by loading custom cop definitions
          # from the configured directories and .rubocop.yml
        end
      end
    end
  end
end
