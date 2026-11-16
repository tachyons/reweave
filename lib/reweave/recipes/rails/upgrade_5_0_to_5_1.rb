# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 5.0 -> 5.1 syntax upgrades
      class Upgrade50To51 < Recipe
        display_name "Upgrade Rails 5.0 to 5.1"
        description "Converts Rails 5.0 syntax to 5.1: form_with, secrets management, etc."

        option :convert_form_for, type: [TrueClass, FalseClass], default: true, description: "Convert form_for to form_with"
        option :convert_secrets, type: [TrueClass, FalseClass], default: true, description: "Convert secrets.yml to credentials"

        def get_visitor(context)
          Upgrade50To51Visitor.new(context, config)
        end
      end

      class Upgrade50To51Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert form_for to form_with
          if @config[:convert_form_for] && match_call?(node, method: :form_for)
            replace_location(node.message_loc, "form_with")
            # Also need to convert url: to model: or scope:
          end

          # Convert secrets to credentials
          if @config[:convert_secrets] && match_call?(node, method: :secrets)
            replace_location(node.message_loc, "credentials")
          end

          super
        end
      end
    end
  end
end
