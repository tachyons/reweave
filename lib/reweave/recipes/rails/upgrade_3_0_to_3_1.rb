# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 3.0 -> 3.1 syntax upgrades
      class Upgrade30To31 < Recipe
        display_name "Upgrade Rails 3.0 to 3.1"
        description "Converts Rails 3.0 syntax to 3.1: asset pipeline, reversible migrations, etc."

        option :convert_assets, type: [TrueClass, FalseClass], default: true, description: "Convert asset paths"
        option :convert_migrations, type: [TrueClass, FalseClass], default: true, description: "Convert reversible migrations"

        def get_visitor(context)
          Upgrade30To31Visitor.new(context, config)
        end
      end

      class Upgrade30To31Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert image_tag, stylesheet_link_tag, javascript_include_tag with old asset paths
          # Asset pipeline changes: public/images -> app/assets/images
          if @config[:convert_assets] && match_call?(node, method: :image_tag)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode)
              path = args.first.unescaped
              if path.start_with?("/images/")
                new_path = path.sub("/images/", "")
                replace(args.first, "\"#{new_path}\"")
              end
            end
          end

          # stylesheet_link_tag with old paths
          if @config[:convert_assets] && match_call?(node, method: :stylesheet_link_tag)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode)
              path = args.first.unescaped
              if path.start_with?("/stylesheets/")
                new_path = path.sub("/stylesheets/", "")
                replace(args.first, "\"#{new_path}\"")
              end
            end
          end

          # javascript_include_tag with old paths
          if @config[:convert_assets] && match_call?(node, method: :javascript_include_tag)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode)
              path = args.first.unescaped
              if path.start_with?("/javascripts/")
                new_path = path.sub("/javascripts/", "")
                replace(args.first, "\"#{new_path}\"")
              end
            end
          end

          # Convert reversible migrations: change instead of up/down
          if @config[:convert_migrations] && match_call?(node, method: :change)
            # Already correct in 3.1+
          end

          # up/down -> change (this is more complex, would need class-level analysis)
          # Skip for now

          super
        end
      end
    end
  end
end
