# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module StaticAnalysis
      # Map RuboCop rules to Reweave recipes for auto-fixing
      class RuboCopMapping < Reweave::Recipe::DeclarativeRecipe
        display_name "RuboCop Rule Mapping"
        description "Map RuboCop cops to Reweave recipes for auto-fixing violations"

        option :target_cops, type: Array, default: [], description: "Specific cops to target (empty = all mappable)"
        option :only_safe, type: [TrueClass, FalseClass], default: true, description: "Only apply safe auto-corrections"

        # Style/HashSyntax - convert hash rockets to symbol keys
        transform_hash do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Style/HashSyntax")
          next unless instance.config[:only_safe]

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

        # Style/Lambda - convert lambda arrows
        transform_lambda do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Style/Lambda")

          if node.opening_loc && node.opening_loc.slice == "->"
            node.replace_location(node.opening_loc, "lambda")
          end
        end

        # Style/BlockDelimiters - braces vs do/end
        transform_block_params do |node, instance|
          # This would need more complex logic to handle brace vs do/end
        end

        # Layout/SpaceInsideHashLiteralBraces
        transform_hash do |node, instance|
          next unless instance.config[:target_cops].empty? || instance.config[:target_cops].include?("Layout/SpaceInsideHashLiteralBraces")

          node.prism_node.elements.each do |elem|
            next unless elem.is_a?(Prism::AssocNode)
            # Add space inside braces
          end
        end
      end
    end
  end
end
