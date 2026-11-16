# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 3.0 -> 3.1 syntax upgrades
      class Upgrade30To31 < Recipe
        display_name "Upgrade Rails 3.0 to 3.1"
        description "Converts Rails 3.0 syntax to 3.1: asset pipeline, reversible migrations, etc."

        option :convert_assets, type: [TrueClass, FalseClass], default: true, description: "Convert asset paths"
        option :convert_migrations, type: [TrueClass, FalseClass], default: true, description: "Convert reversible migrations"

        def get_visitor(context)
          Upgrade30To31Visitor.new(context, config)
        end
      end

      class Upgrade30To31Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert image_tag with old paths
          # This is minimal for now
          super
        end
      end
    end
  end
end
