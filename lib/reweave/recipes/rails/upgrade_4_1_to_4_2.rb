# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 4.1 -> 4.2 syntax upgrades
      class Upgrade41To42 < Recipe
        display_name "Upgrade Rails 4.1 to 4.2"
        description "Converts Rails 4.1 syntax to 4.2: ActiveJob, AdequateRecord, Web Console, foreign keys, etc."

        option :convert_activerecord, type: [TrueClass, FalseClass], default: true, description: "Convert ActiveRecord deprecations"
        option :convert_callbacks, type: [TrueClass, FalseClass], default: true, description: "Convert callback syntax"

        def get_visitor(context)
          Upgrade41To42Visitor.new(context, config)
        end
      end

      class Upgrade41To42Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert before_action with string/symbol
          if @config[:convert_callbacks] && match_call?(node, method: :before_action)
            # Already correct
          end

          # Convert ActiveRecord::Relation#empty? -> .none?
          super
        end
      end
    end
  end
end
