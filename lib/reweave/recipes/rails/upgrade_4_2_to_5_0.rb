# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 4.2 -> 5.0 syntax upgrades
      class Upgrade42To50 < Recipe
        display_name "Upgrade Rails 4.2 to 5.0"
        description "Converts Rails 4.2 syntax to 5.0: ActionController::Parameters, ActiveRecord::Base belongs_to required, etc."

        option :convert_controller_params, type: [TrueClass, FalseClass], default: true, description: "Convert params.permit to strong parameters"
        option :convert_belongs_to, type: [TrueClass, FalseClass], default: true, description: "Add optional: true to belongs_to"
        option :convert_before_action, type: [TrueClass, FalseClass], default: true, description: "Convert before_filter to before_action"

        def get_visitor(context)
          Upgrade42To50Visitor.new(context, config)
        end
      end

      class Upgrade42To50Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert before_filter to before_action
          if @config[:convert_before_action] && match_call?(node, method: :before_filter)
            replace_location(node.message_loc, "before_action")
          end

          # Convert after_filter to after_action
          if @config[:convert_before_action] && match_call?(node, method: :after_filter)
            replace_location(node.message_loc, "after_action")
          end

          # Convert skip_before_filter to skip_before_action
          if @config[:convert_before_action] && match_call?(node, method: :skip_before_filter)
            replace_location(node.message_loc, "skip_before_action")
          end

          # Convert belongs_to without optional
          if @config[:convert_belongs_to] && match_call?(node, method: :belongs_to)
            args = extract_arguments(node)
            if args.size == 1
              # belongs_to :name -> belongs_to :name, optional: true
              replace(node, "#{source_for(node.receiver)}.belongs_to(#{source_for(args[0])}, optional: true)")
            elsif args.size == 2
              second = args[1]
              if second.is_a?(Prism::HashNode)
                has_optional = second.elements.any? do |e|
                  e.is_a?(Prism::AssocNode) && e.key.is_a?(Prism::SymbolNode) && e.key.value == "optional"
                end
                unless has_optional
                  # Add optional: true
                  new_hash = source_for(second).sub(/\}$/, ", optional: true}")
                  replace(node, "#{source_for(node.receiver)}.belongs_to(#{source_for(args[0])}, #{new_hash})")
                end
              end
            end
          end

          super
        end
      end
    end
  end
end
