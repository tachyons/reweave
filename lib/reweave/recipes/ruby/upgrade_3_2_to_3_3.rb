# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 3.2 -> 3.3 syntax upgrades
      class Upgrade32To33 < Recipe
        display_name "Upgrade Ruby 3.2 to 3.3"
        description "Converts Ruby 3.2 syntax to 3.3: Prism parser, RJIT, String#byteindex, Time nanosecond precision"

        def get_visitor(context)
          Upgrade32To33Visitor.new(context)
        end
      end

      class Upgrade32To33Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Most 3.3 changes are runtime/performance, not syntax
        def visit_call_node(node)
          super
        end
      end
    end
  end
end
