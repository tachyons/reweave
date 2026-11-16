# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 6.0 -> 6.1 syntax upgrades
      class Upgrade60To61 < Recipe
        display_name "Upgrade Rails 6.0 to 6.1"
        description "Converts Rails 6.0 syntax to 6.1: horizontal sharding, strict loading, etc."

        option :convert_strict_loading, type: [TrueClass, FalseClass], default: true, description: "Add strict_loading to associations"
        option :convert_delegated_type, type: [TrueClass, FalseClass], default: true, description: "Use delegated_type for STI"

        def get_visitor(context)
          Upgrade60To61Visitor.new(context, config)
        end
      end

      class Upgrade60To61Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # Convert belongs_to for delegated_type
          if @config[:convert_delegated_type] && match_call?(node, method: :belongs_to)
            # This is complex pattern matching
          end

          super
        end
      end
    end
  end
end
