# frozen_string_literal: true

require_relative "symbol_table"
require_relative "symbol_collector"
require_relative "type_collector"
require_relative "type_table"

module Reweave
  module Semantic
    # Builds a SymbolTable and TypeTable by scanning all source files in a Project.
    #
    # The analyzer walks every valid Ruby source file, collects method and
    # constant definitions, and produces a cross-file symbol index and type
    # index that recipes can query for context-aware transformations.
    class Analyzer
      def initialize(project)
        @project = project
      end

      # Analyze all source files in the project and return a populated
      # SymbolTable and TypeTable.
      def analyze
        symbol_table = SymbolTable.new
        type_table = TypeTable.new

        @project.valid_source_files.each do |source_file|
          # Collect symbols
          collector = SymbolCollector.new(symbol_table, source_file.path, source: source_file.source)
          collector.run(source_file.root)

          # Collect types
          type_collector = TypeCollector.new(nil, symbol_table, source_file)
          type_collector.run(source_file.root)
          type_table.merge!(type_collector.type_table)
        end

        AnalysisResult.new(symbol_table, type_table)
      end
    end

    # Combined analysis result
    class AnalysisResult
      attr_reader :symbol_table, :type_table

      def initialize(symbol_table, type_table)
        @symbol_table = symbol_table
        @type_table = type_table
      end
    end
  end
end
