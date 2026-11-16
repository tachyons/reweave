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
            next unless elem.is_a?(Prism::AssocNode)
            next unless elem.key.is_a?(Prism::SymbolNode)

            key_loc = elem.key.location
            operator_loc = elem.operator_loc

            if operator_loc && operator_loc.slice == "=>"
              new_key = key_loc.slice.sub(/^:/, "") + ":"
              start_offset = key_loc.start_offset
              end_offset = operator_loc.end_offset
              @edits.add(Editing.replace(source_id, start_offset, end_offset, new_key, recipe_name))
            end
          end
          super
        end

        # Remove require 'rubygems' / require "rubygems"
        def visit_call_node(node)
          return super unless @config[:remove_require_rubygems]

          if match_call?(node, method: :require)
            args = extract_arguments(node)
            if args.size == 1 && args.first.is_a?(Prism::StringNode)
              value = args.first.unescaped
              if value == "rubygems"
                replace(node, "")
              end
            end
          end
          super
        end

        # Convert block arguments: |a, b| -> |a, b| (trailing comma handled by parser)
        # Convert |a| -> |_1| for single arg when enabled
        def visit_block_parameters_node(node)
          return super unless @config[:convert_block_args]

          if node.parameters.size == 1 && node.parameters.first.is_a?(Prism::RequiredParameterNode)
            param = node.parameters.first
            if param.name == "x" || param.name == "y" || param.name == "it" || param.name.start_with?("_")
              replace_location(param.location, "it")
            end
          end
          super
        end
      end
    end
  end
end
