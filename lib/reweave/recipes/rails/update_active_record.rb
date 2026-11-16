# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Update deprecated ActiveRecord methods
      class UpdateActiveRecord < Recipe
        display_name "Update ActiveRecord"
        description "Updates deprecated ActiveRecord methods to modern equivalents"

        def get_visitor(context)
          UpdateActiveRecordVisitor.new(context)
        end
      end

      class UpdateActiveRecordVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # update_attributes -> update
          if node.name == :update_attributes
            replace_method_name(node, :update)
          end

          # update_attributes! -> update!
          if node.name == :update_attributes!
            replace_method_name(node, :update!)
          end

          # destroy_all with conditions -> where(...).destroy_all
          if node.name == :destroy_all
            args = extract_arguments(node)
            unless args.empty?
              # This is a complex transformation, skip for safety
            end
          end

          # delete_all with conditions -> where(...).delete_all
          if node.name == :delete_all
            args = extract_arguments(node)
            unless args.empty?
              # This is a complex transformation, skip for safety
            end
          end

          # first/last with order -> order(...).first/last
          if (node.name == :first || node.name == :last) && call_with_args?(node, 1)
            arg = first_arg(node, Prism::HashNode)
            if arg
              # Could have order: { created_at: :desc }
            end
          end

          super
        end
      end
    end
  end
end
