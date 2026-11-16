# frozen_string_literal: true

require_relative "symbol_table"
require_relative "symbol_collector"

module Reweave
  module Semantic
    # Builds a SymbolTable by scanning all source files in a Project.
    #
    # The analyzer walks every valid Ruby source file, collects method and
    # constant definitions, and produces a cross-file symbol index that
    # recipes can query for context-aware transformations.
    class Analyzer
      def initialize(project)
        @project = project
      end

      # Analyze all source files in the project and return a populated
      # SymbolTable.
      def analyze
        table = SymbolTable.new
        @project.valid_source_files.each do |source_file|
          collector = SymbolCollector.new(table, source_file.path, source: source_file.source)
          collector.run(source_file.root)
        end
        table
      end
    end
  end
end
