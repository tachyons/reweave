# frozen_string_literal: true

require_relative "../../../reweave/recipe/scanning_recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Composite recipe that scans for method definitions and calls, then removes unused methods
      class RemoveUnusedMethods < CompositeRecipe
        display_name "Remove unused methods"
        description "Finds and removes method definitions that are never called"

        def initialize(**options)
          scanner = FindMethodDefinitions.new(**options)
          remover = RemoveUnusedMethodVisitor.new(scanner)
          super([scanner, remover], **options)
        end

        # Scanning phase: find all method definitions and calls
        class FindMethodDefinitions < ScanningRecipe
          display_name "Find method definitions"
          description "Scans for all method definitions and calls"

          attr_reader :accumulator

          def initial_accumulator
            {definitions: {}, calls: Set.new}
          end

          def scan(source_file, accumulator, context)
            @accumulator = accumulator
            visitor = DefinitionScanner.new(context, source_file, accumulator)
            visitor.traverse(source_file.root)
          end

          def generate(accumulator, project)
            # No file generation for this phase
            []
          end

          class DefinitionScanner < Reweave::Visitor::RubyVisitor
            def initialize(context, source_file, accumulator)
              super(context, source_file)
              @accumulator = accumulator
              @source_file = source_file
            end

            def visit_def_node(node)
              method_name = node.name.to_s
              @accumulator[:definitions][method_name] = {
                node: node,
                file: @source_file.path,
                line: node.location.start_line
              }
              super
            end

            def visit_call_node(node)
              @accumulator[:calls].add(node.name.to_s)
              super
            end
          end
        end

        # Transformation phase: remove unused methods
        class RemoveUnusedMethodVisitor < Reweave::Visitor::RubyVisitor
          def initialize(scanner)
            super(nil, nil)
            @scanner = scanner
          end

          def run(source_file)
            @accumulator = @scanner.accumulator
            @source_file = source_file
            traverse(source_file.root)
            edits
          end

          def visit_def_node(node)
            method_name = node.name.to_s
            # Check if this method is called anywhere
            calls = @accumulator[:calls]
            return super if calls.include?(method_name)

            # Method is unused, remove it
            delete(node)
            super
          end
        end
      end
    end
  end
end
