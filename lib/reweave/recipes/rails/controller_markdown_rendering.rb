# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Replace render markdown: with native Rails 8 render markdown:
      class ControllerMarkdownRendering < Recipe
        display_name "Controller markdown rendering"
        description "Replaces render markdown: with native Rails 8 render markdown:"

        def get_visitor(context)
          ControllerMarkdownRenderingVisitor.new(context)
        end
      end

      class ControllerMarkdownRenderingVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # render markdown: "content" -> render markdown: "content" (already correct in Rails 8)
          # render inline: "...", type: :markdown -> render markdown: "..."
          if match_call?(node, method: :render)
            kwargs = extract_keyword_arguments(node)
            if kwargs[:type]&.is_a?(Prism::SymbolNode) && kwargs[:type].value == :markdown
              if kwargs[:inline]
                # Replace render inline: "...", type: :markdown with render markdown: "..."
                replace(node, "render markdown: #{kwargs[:inline].slice}")
              end
            end
          end

          super
        end
      end
    end
  end
end
