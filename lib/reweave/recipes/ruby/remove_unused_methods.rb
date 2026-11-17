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
          super([scanner, RemoveUnusedMethodsRemover.new(scanner)], **options)
        end

        # Scanning phase: find all method definitions and calls
        class FindMethodDefinitions < ScanningRecipe
          display_name "Find method definitions"
          description "Scans for all method definitions and calls"

          def initial_accumulator
            {definitions: {}, calls: Set.new}
          end

          def scan(source_file, accumulator, context)
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

        # Transformation phase: removes definitions the scan phase found unused.
        # A proper Recipe (not a bare visitor) so the engine can drive it.
        class RemoveUnusedMethodsRemover < Recipe
          display_name "Remove unused method definitions"
          description "Deletes method definitions that are never called anywhere in the project"

          def initialize(scanner = nil)
            @scanner = scanner
            super()
          end

          # The engine hands arity-2 get_visitor the accumulators hash so this
          # recipe can read the scan phase's results (Engine#create_visitor).
          def get_visitor(accumulators, context)
            return unless accumulators.key?(@scanner)

            RemoveUnusedMethodVisitor.new(context, accumulators[@scanner][:calls])
          end
        end

        class RemoveUnusedMethodVisitor < Reweave::Visitor::RubyVisitor
          def initialize(context, calls)
            super(context, nil)
            @calls = calls
          end

          def run(source_file)
            @source_file = source_file
            traverse(source_file.root)
            edits
          end

          def visit_def_node(node)
            method_name = node.name.to_s
            # Check if this method is called anywhere
            return super if @calls.include?(method_name)

            # Method is unused, remove it
            delete(node)
            super
          end
        end
      end
    end
  end
end
