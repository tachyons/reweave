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
              via = kwargs[:via]
              if via
                # match "/path", via: :post -> post "/path"
                method = via.is_a?(Prism::SymbolNode) ? via.value : "get"
                replace(node, "#{method} #{source_for(args.first)}")
              else
                replace_location(node.message_loc, "get")
              end
            end
          end

          # constraints(id: /regex/) -> already correct, just ensure it's used properly
          if match_call?(node, method: :constraints)
            # constraints(id: /regex/) is already correct
            # But we can flag nested constraints
          end

          # namespace :admin do ... end -> already correct
          # scope :admin do ... end -> already correct

          # resources :users -> already correct
          # resource :user -> already correct

          # root "home#index" -> already correct

          # get "/login" -> already correct
          # post "/login" -> already correct

          super
        end
      end
    end
  end
end
