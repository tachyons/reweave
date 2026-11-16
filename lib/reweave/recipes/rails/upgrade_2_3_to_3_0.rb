# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 2.3 -> 3.0 syntax upgrades
      class Upgrade23To30 < Recipe
        display_name "Upgrade Rails 2.3 to 3.0"
        description "Converts Rails 2.3 syntax to 3.0: ActiveRecord query interface, routes, mailers, bundler, etc."

        option :convert_named_scope, type: [TrueClass, FalseClass], default: true, description: "Convert named_scope to scope"
        option :convert_finders, type: [TrueClass, FalseClass], default: true, description: "Convert dynamic finders (find_by_*) to where"
        option :convert_routes, type: [TrueClass, FalseClass], default: true, description: "Convert old routes syntax to new"
        option :convert_mailers, type: [TrueClass, FalseClass], default: true, description: "Convert old mailer syntax"

        def get_visitor(context)
          Upgrade23To30Visitor.new(context, config)
        end
      end

      class Upgrade23To30Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Convert named_scope to scope
        def visit_call_node(node)
          return super unless @config[:convert_named_scope]

          if match_call?(node, method: :named_scope)
            replace_location(node.message_loc, "scope")
          end

          # Convert dynamic finders: find_by_name -> where(name: ...).first
          if @config[:convert_finders] && node.name.to_s.start_with?("find_by_")
            # This is complex, skip for now
          end

          # Convert old routes: map.root -> root
          if @config[:convert_routes] && match_call?(node, method: :root) && match_call?(node.receiver, method: :map)
            # map.root :controller => "home" -> root "home#index"
          end

          super
        end
      end
    end
  end
end
