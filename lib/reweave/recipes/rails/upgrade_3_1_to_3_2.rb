# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 3.1 -> 3.2 syntax upgrades
      class Upgrade31To32 < Recipe
        display_name "Upgrade Rails 3.1 to 3.2"
        description "Converts Rails 3.1 syntax to 3.2: key-value store, tagged logging, etc."

        option :convert_key_value_store, type: [TrueClass, FalseClass], default: true, description: "Convert key-value store syntax"

        def get_visitor(context)
          Upgrade31To32Visitor.new(context, config)
        end
      end

      class Upgrade31To32Visitor < Reweave::Visitor::RubyVisitor
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
          super
        end
      end
    end
  end
end
