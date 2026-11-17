# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Inject stopping? checks for ActiveJob continuations
      class ActiveJobContinuations < Recipe
        display_name "ActiveJob continuations"
        description "Injects stopping? checks in ActiveJob perform methods for SolidQueue"

        def get_visitor(context)
          ActiveJobContinuationsVisitor.new(context)
        end
      end

      class ActiveJobContinuationsVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_def_node(node)
          # Check if this is a perform method in an ActiveJob class
          return super unless node.name == :perform

          # Check if parent is a class that inherits from ApplicationJob or ActiveJob::Base
          cursor = self.cursor
          if cursor
            ancestors = cursor.ancestors
            is_job_class = ancestors.any? do |ancestor|
              ancestor.node.is_a?(Prism::ClassNode) &&
                (ancestor.node.superclass&.slice&.include?("ApplicationJob") ||
                 ancestor.node.superclass&.slice&.include?("ActiveJob::Base"))
            end

            if is_job_class
              # Add stopping? check at the beginning of the method
              body = node.body
              if body&.is_a?(Prism::StatementsNode) && body.body&.any?
                first_stmt = body.body.first
                insert_before(first_stmt, "return if stopping?\n  ")
              elsif body&.is_a?(Prism::StatementsNode) && body.body&.empty?
                # Empty method, add the check
                insert_after(node.opening_loc || node.name_loc, "\n  return if stopping?")
              end
            end
          end

          super
        end
      end
    end
  end
end
