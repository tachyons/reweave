# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 1.8 -> 1.9 syntax upgrades
      class Upgrade18To19 < Recipe
        display_name "Upgrade Ruby 1.8 to 1.9"
        description "Converts Ruby 1.8 syntax to 1.9: hash rockets, block args, require rubygems, etc."

        option :convert_hash_arrows, type: [TrueClass, FalseClass], default: true, description: "Convert :key => value to key: value"
        option :remove_require_rubygems, type: [TrueClass, FalseClass], default: true, description: "Remove require 'rubygems'"
        option :convert_symbol_array, type: [TrueClass, FalseClass], default: true, description: "Convert [:a, :b] to %i[a b] (2.0+)"

        def get_visitor(context)
          Upgrade18To19Visitor.new(context, config)
        end
      end

      class Upgrade18To19Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Convert :key => value to key: value
        def visit_hash_node(node)
          return super unless @config[:convert_hash_arrows]

          node.elements.each do |elem|
            convert_hash_rocket_to_symbol_key(elem)
          end
          super
        end

        # Remove require 'rubygems' / require "rubygems"
        def visit_call_node(node)
          return super unless @config[:remove_require_rubygems]

          if match_call?(node, method: :require)
            arg = first_arg(node, Prism::StringNode)
            if arg && string_node?(arg, "rubygems")
              replace(node, "")
            end
          end
          super
        end

        # Convert block arguments: |a, b| -> |a, b| (trailing comma handled by parser)
        # Convert |a| -> |_1| for single arg when enabled
        def visit_block_parameters_node(node)
          return super unless @config[:convert_block_args]

          inner_params = node.parameters
          requireds = inner_params.requireds
          if requireds.size == 1 && inner_params.optionals.empty? && inner_params.rest.nil?
            param = requireds.first
            if %w[x y it].include?(param.name) || param.name.start_with?("_")
              replace_location(param.location, "it")
            end
          end
          super
        end
      end
    end
  end
end
