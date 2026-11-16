# frozen_string_literal: true

require_relative "../../../reweave/recipe/scanning_recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Scanning recipe that finds all method calls across the project
      class FindMethodCalls < ScanningRecipe
        display_name "Find method calls"
        description "Scans the project and collects all method calls with their receivers"

        def initial_accumulator
          {calls: []}
        end

        def scan(source_file, accumulator, context)
          visitor = FindMethodCallsVisitor.new(context, source_file, accumulator)
          visitor.traverse(source_file.root)
        end

        def generate(accumulator, project)
          # Generate a summary report file
          calls = accumulator[:calls]
          return [] if calls.empty?

          content = "# Method Call Analysis Report\n\n"
          content += "Total calls found: #{calls.size}\n\n"

          # Group by method name
          by_method = calls.group_by { |c| c[:method] }
          by_method.each do |method, method_calls|
            content += "## #{method} (#{method_calls.size} calls)\n"
            method_calls.each do |call|
              receiver = call[:receiver] ? "#{call[:receiver]}." : ""
              content += "  - #{receiver}#{method} at #{call[:file]}:#{call[:line]}\n"
            end
            content += "\n"
          end

          [Reweave::Results::FileChange.new(
            path: "method_calls_report.md",
            original_source: "",
            updated_source: content,
            recipes: [display_name],
            change_type: :created
          )]
        end

        class FindMethodCallsVisitor < Reweave::Visitor::RubyVisitor
          def initialize(context, source_file, accumulator)
            super(context, source_file)
            @accumulator = accumulator
            @source_file = source_file
          end

          def visit_call_node(node)
            receiver_name = extract_receiver_name(node)
            @accumulator[:calls] << {
              method: node.name,
              receiver: receiver_name,
              file: @source_file.path,
              line: node.location.start_line
            }
            super
          end
        end
      end
    end
  end
end
