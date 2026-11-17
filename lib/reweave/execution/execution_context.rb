# frozen_string_literal: true

require_relative "../../reweave/semantic/symbol_table"

module Reweave
  module Execution
    class ExecutionContext
      attr_reader :project_root, :dry_run, :max_cycles, :logger, :diagnostics, :messages, :metadata, :stats
      attr_accessor :symbol_table, :type_table

      def initialize(project_root: ".", dry_run: true, max_cycles: 10, logger: nil)
        @project_root = File.expand_path(project_root)
        @dry_run = dry_run
        @max_cycles = max_cycles
        @logger = logger || default_logger
        @diagnostics = []
        @messages = []
        @metadata = {}
        @stats = {
          files_scanned: 0,
          files_matched: 0,
          files_changed: 0,
          files_created: 0,
          files_deleted: 0,
          cycles: 0,
          recipes_executed: 0,
          total_edits: 0
        }
        @symbol_table = Semantic::SymbolTable.new
        @cancelled = false
      end

      def log(level, message)
        @logger.call(level, message)
      end

      def info(message)
        log(:info, message)
      end

      def warn(message)
        log(:warn, message)
      end

      def error(message)
        log(:error, message)
      end

      def debug(message)
        log(:debug, message)
      end

      def add_diagnostic(diagnostic)
        @diagnostics << diagnostic
      end

      def add_message(message)
        @messages << message
      end

      def cancel!
        @cancelled = true
      end

      def cancelled?
        @cancelled
      end

      def increment_stat(key, amount = 1)
        @stats[key] += amount
      end

      def to_h
        {
          project_root: @project_root,
          dry_run: @dry_run,
          max_cycles: @max_cycles,
          stats: @stats,
          diagnostics: @diagnostics,
          messages: @messages
        }
      end

      private

      def default_logger
        ->(level, message) { puts "[#{level.upcase}] #{message}" }
      end
    end
  end
end
