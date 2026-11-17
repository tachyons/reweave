# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module StaticAnalysis
      # Auto-fix common static analysis violations (Style, Layout, Lint)
      class AutoFix < Reweave::Recipe::DeclarativeRecipe
        display_name "Auto-fix Static Analysis Violations"
        description "Automatically fix common Style, Layout, and Lint violations"

        option :target_cops, type: Array, default: [], description: "Specific cops to fix (empty = all)"
        option :only_safe, type: [TrueClass, FalseClass], default: true, description: "Only apply safe corrections"

        # Style/HashSyntax - convert hash rockets to symbol keys
        transform_hash do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Style/HashSyntax")

          node.prism_node.elements.each do |elem|
            next unless elem.is_a?(Prism::AssocNode)
            next unless elem.key.is_a?(Prism::SymbolNode)
            next unless elem.operator_loc&.slice == "=>"

            new_key = elem.key.location.slice.sub(/^:/, "") + ":"
            loc = Struct.new(:start_offset, :end_offset).new(
              elem.key.location.start_offset,
              elem.operator_loc.end_offset
            )
            node.replace_location(loc, new_key)
          end
        end

        # Style/Lambda - convert -> to lambda
        transform_lambda do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Style/Lambda")

          if node.opening_loc && node.opening_loc.slice == "->"
            node.replace_location(node.opening_loc, "lambda")
          end
        end

        # Layout/SpaceInsideHashLiteralBraces - add spaces inside braces
        transform_hash do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Layout/SpaceInsideHashLiteralBraces")

          node.prism_node.elements.each do |elem|
            next unless elem.is_a?(Prism::AssocNode)
            # Add space after { and before }
            if elem.key.location.start_offset > node.prism_node.opening_loc.end_offset
              # Already has space
            else
              # Add space after {
              loc = Struct.new(:start_offset, :end_offset).new(
                node.prism_node.opening_loc.end_offset,
                node.prism_node.opening_loc.end_offset
              )
              node.replace_location(loc, " ")
            end
          end
        end

        # Style/SingleLineBlockParams - convert block args for single-line blocks
        transform_block_params do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Style/SingleLineBlockParams")

          inner_params = node.parameters
          requireds = inner_params.requireds
          if requireds.size == 1 && inner_params.optionals.empty? && inner_params.rest.nil?
            param = requireds.first
            if %w[x y it].include?(param.name) || param.name.start_with?("_")
              node.replace_location(param.location, "_1")
            end
          end
        end

        # Lint/UnusedMethodArgument - prefix unused args with _
        transform_def do |node, instance|
          # This would need more complex logic to detect unused arguments
        end

        # Lint/UnusedBlockArgument - prefix unused block args with _
        transform_block_params do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Lint/UnusedBlockArgument")

          inner_params = node.parameters
          inner_params.requireds
          # Check if any required params are unused
          # See https://github.com/tachyons/reweave/issues/36
        end
      end
    end
  end
end
