# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 8.0 -> 8.1 syntax upgrades (future)
      class Upgrade80To81 < Recipe
        display_name "Upgrade Rails 8.0 to 8.1"
        description "Converts Rails 8.0 syntax to 8.1: placeholder for future changes"

        def get_visitor(context)
          Upgrade80To81Visitor.new(context)
        end
      end

      class Upgrade80To81Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # Rails 8.1 changes TBD
          super
        end
      end
    end
  end
end
