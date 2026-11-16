# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Remove gems that are now built into Rails
      class RemoveDeprecatedGems < Recipe
        display_name "Remove deprecated gems"
        description "Removes gems that have been replaced by Rails built-ins (e.g., spring, listen, web-console)"

        DEPRECATED_GEMS = %w[
          spring
          listen
          web-console
          byebug
          capistrano
          capistrano-rails
          capistrano-bundler
          capistrano-rvm
          capistrano-passenger
        ].freeze

        def get_visitor(context)
          RemoveDeprecatedGemsVisitor.new(context)
        end
      end

      class RemoveDeprecatedGemsVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # Match gem 'spring' in Gemfile
          if node.name == :gem
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode)
              gem_name = args.first.value
              if RemoveDeprecatedGems::DEPRECATED_GEMS.include?(gem_name)
                # Delete the entire gem line
                delete(node)
              end
            end
          end

          # Match gem 'spring', group: :development
          if node.name == :gem
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode)
              gem_name = args.first.value
              if RemoveDeprecatedGems::DEPRECATED_GEMS.include?(gem_name)
                delete(node)
              end
            end
          end

          super
        end
      end
    end
  end
end
