# frozen_string_literal: true

require "fileutils"
require_relative "execution_context"
require_relative "project"
require_relative "../../reweave/results/execution_result"
require_relative "../../reweave/results/changeset"
require_relative "../../reweave/recipe/scanning_recipe"

module Reweave
  module Execution
    class Engine
      attr_reader :context

      def initialize(dry_run: true, max_cycles: 10)
        @dry_run = dry_run
        @max_cycles = max_cycles
        @processed_file_ops = Set.new
      end

      def run(recipe, path: ".", source: nil)
        @context = ExecutionContext.new(
          project_root: path,
          dry_run: @dry_run,
          max_cycles: @max_cycles
        )

        begin
          if source
            execute_on_source(recipe, source)
          else
            execute_on_project(recipe, path)
          end
        rescue => e
          @context.error("Execution failed: #{e.message}")
          return Results::ExecutionResult.new(
            change_set: Results::ChangeSet.new,
            diagnostics: @context.diagnostics,
            stats: @context.stats,
            context: @context,
            success: false,
            error: e.message
          )
        end

        Results::ExecutionResult.new(
          change_set: @change_set,
          diagnostics: @context.diagnostics,
          stats: @context.stats,
          context: @context,
          success: true
        )
      end

      private

      def execute_on_source(recipe, source)
        source_file = SourceFile.new(path: "(string)", source: source)
        @change_set = Results::ChangeSet.new

        run_recipes_on_file(recipe, source_file)

        if source_file.source != source
          @change_set.add(Results::FileChange.new(
            path: source_file.path,
            original_source: source,
            updated_source: source_file.source,
            recipes: [recipe.display_name],
            change_type: :modified
          ))
        end
      end

      def execute_on_project(recipe, path)
        project = Project.from_path(path)
        @change_set = Results::ChangeSet.new

        # Expand composite recipes
        expanded_recipes = expand_recipes(recipe)

        # Handle scanning recipes first
        scanning_recipes, transformation_recipes = expanded_recipes.partition(&:scanning_recipe?)

        accumulators = {}
        scanning_recipes.each do |scanning_recipe|
          accumulator = scanning_recipe.initial_accumulator
          project.valid_source_files.each do |source_file|
            scanning_recipe.scan(source_file, accumulator, @context)
          end
          accumulators[scanning_recipe] = accumulator
          @context.stats[:recipes_executed] += 1

          # Generate output files from scanning results
          generated_changes = scanning_recipe.generate(accumulator, project)
          generated_changes.each do |change|
            @change_set.add(change)
            if change.created?
              @context.stats[:files_created] += 1
            end
          end
        end

        # In dry-run mode, just run once
        if @dry_run
          transformation_recipes.each do |transformation_recipe|
            break if @context.cancelled?
            run_recipe_on_project(transformation_recipe, project, accumulators)
          end
          @context.stats[:cycles] = 1
          return
        end

        # Run transformation cycles
        cycle = 0
        changed = true

        while changed && cycle < @max_cycles && !@context.cancelled?
          cycle += 1
          @context.stats[:cycles] = cycle
          changed = false

          transformation_recipes.each do |transformation_recipe|
            break if @context.cancelled?

            recipe_changed = run_recipe_on_project(transformation_recipe, project, accumulators)
            changed = true if recipe_changed
          end
        end

        if cycle >= @max_cycles && changed
          @context.warn("Max cycles reached, transformations may not have converged")
        end
      end

      def expand_recipes(recipe)
        expanded = []
        expand_recipe(recipe, expanded, Set.new)
        expanded
      end

      def expand_recipe(recipe, expanded, visited)
        return if visited.include?(recipe.object_id)
        visited.add(recipe.object_id)

        if recipe.is_a?(CompositeRecipe)
          recipe.recipes.each { |r| expand_recipe(r, expanded, visited) }
        else
          expanded << recipe
        end
      end

      def run_recipe_on_project(recipe, project, accumulators)
        any_changed = false

        visitor = create_visitor(recipe, accumulators)
        return false unless visitor

        @context.stats[:recipes_executed] += 1

        project.valid_source_files.each do |source_file|
          break if @context.cancelled?

          @context.stats[:files_scanned] += 1

          edits = run_visitor_on_file(visitor, source_file)

          # Handle file operations after each file visit
          file_ops = visitor.file_operations
          visitor.instance_variable_set(:@file_operations, [])
          file_ops.each do |op|
            # Create a unique key for this file operation to avoid duplicates across cycles
            op_key = case op[:type]
            when :create then [:create, op[:path]]
            when :delete then [:delete, op[:path]]
            when :rename then [:rename, op[:old_path], op[:new_path]]
            end
            next if @processed_file_ops.include?(op_key)
            @processed_file_ops.add(op_key)

            case op[:type]
            when :create
              full_path = File.join(project.root, op[:path])
              if !@dry_run
                FileUtils.mkdir_p(File.dirname(full_path))
                File.write(full_path, op[:contents])
                project.add_source_file(op[:path])
              end
              @change_set.add(Results::FileChange.new(
                path: full_path,
                original_source: "",
                updated_source: op[:contents],
                recipes: [recipe.display_name],
                change_type: :created
              ))
              @context.stats[:files_created] += 1
              any_changed = true
            when :delete
              full_path = File.join(project.root, op[:path])
              if !@dry_run && File.exist?(full_path)
                File.delete(full_path)
                project.remove_source_file(op[:path])
              end
              source_file_for_delete = project.find_source_file(op[:path])
              original = source_file_for_delete&.source || ""
              @change_set.add(Results::FileChange.new(
                path: full_path,
                original_source: original,
                updated_source: "",
                recipes: [recipe.display_name],
                change_type: :deleted
              ))
              @context.stats[:files_deleted] += 1
              any_changed = true
            when :rename
              old_full = File.join(project.root, op[:old_path])
              new_full = File.join(project.root, op[:new_path])
              if !@dry_run && File.exist?(old_full)
                FileUtils.mkdir_p(File.dirname(new_full))
                File.rename(old_full, new_full)
                project.remove_source_file(op[:old_path])
                project.add_source_file(op[:new_path])
              end
              source_file_for_rename = project.find_source_file(op[:old_path])
              original = source_file_for_rename&.source || ""
              @change_set.add(Results::FileChange.new(
                path: old_full,
                original_source: original,
                updated_source: original,
                recipes: [recipe.display_name],
                change_type: :renamed
              ))
              @context.stats[:files_deleted] += 1
              @context.stats[:files_created] += 1
              any_changed = true
            end
          end

          next if edits.empty?

          @context.stats[:files_matched] += 1
          @context.stats[:total_edits] += edits.size

          if !@dry_run
            source_file.apply_edits(edits)
            @change_set.add(Results::FileChange.new(
              path: source_file.path,
              original_source: source_file.source,
              updated_source: source_file.source,
              recipes: [recipe.display_name],
              change_type: :modified
            ))
            @context.stats[:files_changed] += 1
            any_changed = true
          else
            new_source = Editing::Editor.apply(source_file.source.dup, edits)
            if new_source != source_file.source
              @change_set.add(Results::FileChange.new(
                path: source_file.path,
                original_source: source_file.source,
                updated_source: new_source,
                recipes: [recipe.display_name],
                change_type: :modified
              ))
              any_changed = true
            end
          end
        end

        any_changed
      end

      def run_recipes_on_file(recipe, source_file)
        expanded = expand_recipes(recipe)
        expanded.each do |r|
          visitor = create_visitor(r, {})
          next unless visitor

          edits = run_visitor_on_file(visitor, source_file)
          next if edits.empty?

          source_file.apply_edits(edits)
        end
      end

      def create_visitor(recipe, accumulators)
        if recipe.is_a?(ScanningRecipe)
          accumulator = accumulators[recipe]
          recipe.get_visitor(accumulator, @context)
        else
          recipe.get_visitor(@context)
        end
      end

      def run_visitor_on_file(visitor, source_file)
        return Editing::EditSet.new unless visitor

        # Re-parse to get fresh AST
        source_file.reparse!

        # Reset visitor's edits for this file
        visitor.instance_variable_set(:@edits, Editing::EditSet.new)

        # Update visitor's source_file
        visitor.instance_variable_set(:@source_file, source_file)

        # Traverse the AST - use run if available (for visitors that manage their own source_file)
        if visitor.respond_to?(:run)
          visitor.run(source_file)
        else
          visitor.visit(source_file.root)
        end

        visitor.edits
      end
    end
  end
end
