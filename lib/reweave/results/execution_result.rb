# frozen_string_literal: true

require_relative "changeset"

module Reweave
  module Results
    class ExecutionResult
      attr_reader :change_set, :diagnostics, :stats, :context, :success, :error

      def initialize(change_set:, diagnostics:, stats:, context:, success: true, error: nil)
        @change_set = change_set
        @diagnostics = diagnostics
        @stats = stats
        @context = context
        @success = success
        @error = error
      end

      def changed?
        !@change_set.empty?
      end

      def success?
        @success
      end

      def changed_files
        @change_set.changed_files
      end

      def files_changed
        @change_set.size
      end

      def files_modified
        @change_set.modified_files.size
      end

      def files_created
        @change_set.created_files.size
      end

      def files_deleted
        @change_set.deleted_files.size
      end

      def recipes
        @change_set.recipes
      end

      def diffs
        @change_set.map(&:diff).join("\n")
      end

      def to_h
        {
          success: @success,
          error: @error,
          changed: changed?,
          stats: @stats,
          diagnostics: @diagnostics,
          changes: @change_set.map do |c|
            {
              path: c.path,
              change_type: c.change_type,
              recipes: c.recipes,
              diff: c.diff
            }
          end
        }
      end

      def summary
        lines = []
        lines << "Reweave Execution Summary"
        lines << "=" * 30
        lines << "Success: #{@success}"
        lines << "Files scanned: #{@stats[:files_scanned]}"
        lines << "Files matched: #{@stats[:files_matched]}"
        lines << "Files changed: #{@stats[:files_changed]}"
        lines << "Files created: #{@stats[:files_created]}"
        lines << "Files deleted: #{@stats[:files_deleted]}"
        lines << "Cycles: #{@stats[:cycles]}"
        lines << "Recipes executed: #{@stats[:recipes_executed]}"
        lines << "Total edits: #{@stats[:total_edits]}"

        if @error
          lines << ""
          lines << "Error: #{@error}"
        end

        unless @change_set.empty?
          lines << ""
          lines << "Changes:"
          @change_set.each do |c|
            lines << "  #{c.path} (#{c.change_type})"
          end
        end

        lines.join("\n")
      end
    end
  end
end
