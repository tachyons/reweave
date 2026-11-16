# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 7.0 -> 7.1 syntax upgrades
      class Upgrade70To71 < Recipe
        display_name "Upgrade Rails 7.0 to 7.1"
        description "Converts Rails 7.0 syntax to 7.1: ActiveRecord::Encryption, async queries, etc."

        option :convert_encryption, type: [TrueClass, FalseClass], default: true, description: "Convert to ActiveRecord::Encryption"
        option :convert_async, type: [TrueClass, FalseClass], default: true, description: "Convert to async queries"

        def get_visitor(context)
          Upgrade70To71Visitor.new(context, config)
        end
      end

      class Upgrade70To71Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert attr_encrypted to ActiveRecord::Encryption
          if @config[:convert_encryption] && match_call?(node, method: :attr_encrypted)
            # Replace with encrypts
            replace_location(node.message_loc, "encrypts")
          end

          super
        end
      end
    end
  end
end
