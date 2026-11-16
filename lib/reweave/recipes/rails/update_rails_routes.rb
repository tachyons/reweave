# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Update Rails routes syntax
      class UpdateRailsRoutes < Recipe
        display_name "Update Rails routes"
        description "Updates deprecated routes syntax (match, constraints, etc.)"

        def get_visitor(context)
          UpdateRailsRoutesVisitor.new(context)
        end
      end

      class UpdateRailsRoutesVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # match ':controller(/:action(/:id))' -> get ':controller(/:action(/:id))'
          if node.name == :match
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode)
              # Check if it's a simple match without :via
              kwargs = extract_keyword_arguments(node)
              unless kwargs[:via]
                replace_location(node.message_loc, "get")
              end
            end
          end

          # constraints(id: /regex/) -> constraints(id: /regex/) (already correct)
          # namespace :admin do ... end -> namespace :admin do ... end (already correct)

          super
        end
      end
    end
  end
end
