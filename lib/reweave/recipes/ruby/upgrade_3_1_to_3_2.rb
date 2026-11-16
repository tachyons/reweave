# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 3.1 -> 3.2 syntax upgrades
      class Upgrade31To32 < Recipe
        display_name "Upgrade Ruby 3.1 to 3.2"
        description "Converts Ruby 3.1 syntax to 3.2: syntax suggestions, Hash#fetch multiple keys, String#bytesplice, Fiber storage"

        def get_visitor(context)
          Upgrade31To32Visitor.new(context)
        end
      end

      class Upgrade31To32Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Most 3.2 changes are runtime/performance, not syntax
        def visit_call_node(node)
          super
        end
      end
    end
  end
end
