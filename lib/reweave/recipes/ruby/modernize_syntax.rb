# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Modernize Ruby syntax (e.g., old-style hash to new-style)
      class ModernizeSyntax < Recipe
        display_name "Modernize syntax"
        description "Converts old Ruby syntax to modern equivalents"

        option :convert_hash_arrows, type: [TrueClass, FalseClass], default: true, description: "Convert => to : for symbol keys"
        option :convert_lambda_arrows, type: [TrueClass, FalseClass], default: true, description: "Convert ->() to lambda literal"
        option :convert_block_args, type: [TrueClass, FalseClass], default: false, description: "Convert block args to it/_1 syntax"

        def get_visitor(context)
          ModernizeSyntaxVisitor.new(context, config)
        end
      end

      class ModernizeSyntaxVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_hash_node(node)
          return super unless @config[:convert_hash_arrows]

          node.elements.each do |elem|
            next unless elem.is_a?(Prism::AssocNode)
            next unless elem.key.is_a?(Prism::SymbolNode)

            # Convert :key => value to key: value
            key_loc = elem.key.location
            operator_loc = elem.operator_loc

            if operator_loc && operator_loc.start_offset == key_loc.end_offset
              # This is a hash rocket, convert it
              replace_location(operator_loc, ":")
              # Remove the leading colon from the symbol
              replace_location(key_loc, key_loc.slice.sub(/^:/, ""))
            end
          end
          super
        end

        def visit_lambda_node(node)
          return super unless @config[:convert_lambda_arrows]

          # Convert -> { } to lambda { }
          if node.opening_loc && node.opening_loc.slice == "->"
            replace_location(node.opening_loc, "lambda")
          end
          super
        end

        def visit_block_parameters_node(node)
          return super unless @config[:convert_block_args]

          # Convert |x| to |_1| or |it| for single argument
          if node.parameters.size == 1 && node.parameters.first.is_a?(Prism::RequiredParameterNode)
            param = node.parameters.first
            if param.name.start_with?("_") || param.name == "it" || param.name == "x"
              replace_location(param.location, "it")
            end
          end
          super
        end
      end
    end
  end
end
