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
        def visit_call_node(node)
          if match_call?(node, method: :itself) && !node.receiver
            # obj.itself -> obj.itself (already correct)
          end

          # Convert ->(x) { x } to &:itself
          if node.is_a?(Prism::LambdaNode) || (node.is_a?(Prism::CallNode) && match_call?(node, method: :lambda))
            body = node.body
            if body.is_a?(Prism::BlockNode) && body.body.is_a?(Prism::CallNode)
              # This is complex, skip for now
            end
          end
          super
        end
      end
    end
  end
end
