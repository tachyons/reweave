# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Update Rails configuration files
      class UpdateConfiguration < Recipe
        display_name "Update configuration"
        description "Updates deprecated configuration options in config/environments/*.rb, config/application.rb"

        def get_visitor(context)
          UpdateConfigurationVisitor.new(context)
        end
      end

      class UpdateConfigurationVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # config.active_record.belongs_to_required_by_default = true
          # This is a setter, handled by matching the method name
          if match_config_setter?(node, :config, :active_record, method: :belongs_to_required_by_default=)
            # Already correct in Rails 5+
          end

          # config.assets.enabled -> deprecated in Rails 7, remove or set to false
          if match_config_setter?(node, :config, :assets, method: :enabled=)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::TrueNode)
              # config.assets.enabled = true -> config.assets.enabled = false (or remove)
              replace(args.first, "false")
            end
          end

          # config.active_support.halt_callback_chains_on_return_false = true
          if match_config_setter?(node, :config, :active_support, method: :halt_callback_chains_on_return_false=)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::TrueNode)
              replace(args.first, "false")
            end
          end

          # config.active_record.suppress_multiple_database_errors = true
          if match_config_setter?(node, :config, :active_record, method: :suppress_multiple_database_errors=)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::TrueNode)
              replace(args.first, "false")
            end
          end

          super
        end

        def visit_block_node(node)
          # Match config.xxx = value patterns in block context
          super
        end
      end
    end
  end
end
