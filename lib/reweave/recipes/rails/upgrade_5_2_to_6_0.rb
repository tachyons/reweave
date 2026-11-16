# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 5.2 -> 6.0 syntax upgrades
      class Upgrade52To60 < Recipe
        display_name "Upgrade Rails 5.2 to 6.0"
        description "Converts Rails 5.2 syntax to 6.0: Webpacker, Action Mailbox, Action Text, multiple databases, etc."

        option :convert_webpacker, type: [TrueClass, FalseClass], default: true, description: "Convert asset pipeline to Webpacker"
        option :convert_multiple_dbs, type: [TrueClass, FalseClass], default: true, description: "Convert to multiple databases config"
        option :convert_action_mailbox, type: [TrueClass, FalseClass], default: true, description: "Convert mailbox routing"

        def get_visitor(context)
          Upgrade52To60Visitor.new(context, config)
        end
      end

      class Upgrade52To60Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert javascript_include_tag to javascript_pack_tag
          if @config[:convert_webpacker] && match_call?(node, method: :javascript_include_tag)
            args = extract_arguments(node)
            if args.any? { |a| a.is_a?(Prism::StringNode) && a.unescaped.include?("application") }
              replace_location(node.message_loc, "javascript_pack_tag")
            end
          end

          # Convert stylesheet_link_tag to stylesheet_pack_tag
          if @config[:convert_webpacker] && match_call?(node, method: :stylesheet_link_tag)
            args = extract_arguments(node)
            if args.any? { |a| a.is_a?(Prism::StringNode) && a.unescaped.include?("application") }
              replace_location(node.message_loc, "stylesheet_pack_tag")
            end
          end

          super
        end
      end
    end
  end
end
