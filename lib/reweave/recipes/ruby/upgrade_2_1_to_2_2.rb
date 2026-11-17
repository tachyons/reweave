# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.1 -> 2.2 syntax upgrades
      class Upgrade21To22 < Recipe
        display_name "Upgrade Ruby 2.1 to 2.2"
        description "Converts Ruby 2.1 syntax to 2.2: Symbol GC, String#unicode_normalize, Kernel#itself"

        def get_visitor(context)
          Upgrade21To22Visitor.new(context)
        end
      end

      class Upgrade21To22Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Replace obj.method(:itself) or ->(x) { x } with Kernel#itself / :itself.to_proc
        def visit_lambda_node(node)
          # Convert ->(x) { x } to &:itself
          body = node.body
          if body.is_a?(Prism::StatementsNode) && body.body.size == 1
            stmt = body.body.first
            if stmt.is_a?(Prism::LocalVariableReadNode)
              replace(node, "&:itself")
            end
          end
          super
        end

        def visit_call_node(node)
          # Convert lambda { |x| x } to &:itself
          if match_call?(node, method: :lambda)
            block = node.block
            if block&.body&.is_a?(Prism::StatementsNode) && block.body.body.size == 1
              stmt = block.body.body.first
              if stmt.is_a?(Prism::LocalVariableReadNode)
                replace(node, "&:itself")
              end
            end
          end

          super
        end
      end
    end
  end
end
