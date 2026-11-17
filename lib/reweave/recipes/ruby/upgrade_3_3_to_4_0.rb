# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 3.3 -> 4.0 syntax upgrades (speculative/preview)
      class Upgrade33To40 < Recipe
        display_name "Upgrade Ruby 3.3 to 4.0"
        description "Converts Ruby 3.3 syntax to 4.0: breaking changes (see https://github.com/tachyons/reweave/issues/39)"

        def get_visitor(context)
          Upgrade33To40Visitor.new(context)
        end
      end

      class Upgrade33To40Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Ruby 4.0 changes TBD - placeholder for future breaking changes
        def visit_call_node(node)
          super
        end
      end
    end
  end
end
