# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 7.1 -> 7.2 syntax upgrades
      class Upgrade71To72 < Recipe
        display_name "Upgrade Rails 7.1 to 7.2"
        description "Converts Rails 7.1 syntax to 7.2: bracket-free syntax, config.load_defaults, etc."

        option :convert_bracket_free, type: [TrueClass, FalseClass], default: true, description: "Convert to bracket-free syntax where possible"
        option :convert_load_defaults, type: [TrueClass, FalseClass], default: true, description: "Update load_defaults version"

        def get_visitor(context)
          Upgrade71To72Visitor.new(context, config)
        end
      end

      class Upgrade71To72Visitor < Reweave::Visitor::RubyVisitor
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
          # Update config.load_defaults
          if @config[:convert_load_defaults] && match_call?(node, method: :load_defaults)
            args = extract_arguments(node)
            if args.size == 1 && args.first.is_a?(Prism::StringNode)
              version = args.first.unescaped
              if version < "7.2"
                replace(node, "config.load_defaults 7.2")
              end
            end
          end

          super
        end
      end
    end
  end
end
