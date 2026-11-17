# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module Ruby
      # Declarative version of ModernizeSyntax using the new DSL
      class DeclarativeModernizeSyntax < Reweave::Recipe::DeclarativeRecipe
        display_name "Modernize syntax"
        description "Converts old Ruby syntax to modern equivalents"

        option :convert_hash_arrows, type: [TrueClass, FalseClass], default: true, description: "Convert => to : for symbol keys"
        option :convert_lambda_arrows, type: [TrueClass, FalseClass], default: true, description: "Convert ->() to lambda literal"
        option :convert_block_args, type: [TrueClass, FalseClass], default: false, description: "Convert block args to it/_1 syntax"

        # Convert hash rockets to symbol keys
        transform_hash do |node, instance|
          next unless instance.config[:convert_hash_arrows]

          node.prism_node.elements.each do |elem|
            next unless elem.is_a?(Prism::AssocNode)
            next unless elem.key.is_a?(Prism::SymbolNode)
            next unless elem.operator_loc&.slice == "=>"

            new_key = elem.key.location.slice.sub(/^:/, "") + ":"
            # Create a location-like object with start_offset and end_offset
            loc = Struct.new(:start_offset, :end_offset).new(
              elem.key.location.start_offset,
              elem.operator_loc.end_offset
            )
            node.replace_location(loc, new_key)
          end
        end

        # Convert -> to lambda
        transform_lambda do |node, instance|
          next unless instance.config[:convert_lambda_arrows]

          prism_node = node.prism_node
          if prism_node.opening_loc && prism_node.opening_loc.slice == "->"
            node.replace_location(prism_node.opening_loc, "lambda")
          end
        end

        # Convert block arguments to it/_1
        transform_block_params do |node, instance|
          next unless instance.config[:convert_block_args]

          prism_node = node.prism_node
          inner_params = prism_node.parameters
          requireds = inner_params.requireds
          if requireds.size == 1 && inner_params.optionals.empty? && inner_params.rest.nil?
            param = requireds.first
            if %w[x y it].include?(param.name) || param.name.start_with?("_")
              node.replace_location(param.location, "it")
            end
          end
        end
      end
    end
  end
end
