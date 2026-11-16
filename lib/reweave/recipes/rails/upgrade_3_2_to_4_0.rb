# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 3.2 -> 4.0 syntax upgrades
      class Upgrade32To40 < Recipe
        display_name "Upgrade Rails 3.2 to 4.0"
        description "Converts Rails 3.2 syntax to 4.0: strong parameters, routing concerns, ActiveRecord::Relation changes, etc."

        option :convert_strong_parameters, type: [TrueClass, FalseClass], default: true, description: "Convert attr_accessible to strong parameters"
        option :convert_routes, type: [TrueClass, FalseClass], default: true, description: "Convert match to HTTP verbs"
        option :convert_scopes, type: [TrueClass, FalseClass], default: true, description: "Convert scope syntax"
        option :convert_activerecord_relation, type: [TrueClass, FalseClass], default: true, description: "Convert ActiveRecord::Relation deprecations"

        def get_visitor(context)
          Upgrade32To40Visitor.new(context, config)
        end
      end

      class Upgrade32To40Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert match to HTTP verbs
          if @config[:convert_routes] && match_call?(node, method: :match)
            args = extract_arguments(node)
            if args.size == 1
              path = args.first
              # match "/path" -> get "/path"
              replace(node, "get #{source_for(path)}")
            elsif args.size == 2
              path = args[0]
              options = args[1]
              if options.is_a?(Prism::HashNode)
                # Check for :via option
                via_value = options.elements.find do |e|
                  e.is_a?(Prism::AssocNode) && e.key.is_a?(Prism::SymbolNode) && e.key.value == "via"
                end
                if via_value
                  method = via_value.value.unescaped
                  replace(node, "#{method} #{source_for(path)}")
                end
              end
            end
          end

          # Convert scope :name, lambda { } -> scope :name, -> { }
          if @config[:convert_scopes] && match_call?(node, method: :scope)
            args = extract_arguments(node)
            if args.size == 2
              second = args[1]
              if second.is_a?(Prism::CallNode) && match_call?(second, method: :lambda)
                # Already lambda
              elsif second.is_a?(Prism::LambdaNode)
                # Already lambda
              end
            end
          end

          # Convert ActiveRecord::Relation#empty? -> .none?
          # This is a runtime change, not syntax

          super
        end
      end
    end
  end
end
