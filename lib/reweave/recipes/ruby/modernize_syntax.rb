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
            convert_hash_rocket_to_symbol_key(elem)
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
