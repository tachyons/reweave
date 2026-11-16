# frozen_string_literal: true

require "prism"

module Reweave
  module Parser
    module_function

    def parse(source, path: nil)
      result = Prism.parse(source)
      ParseResult.new(source, path, result)
    end
  end

  class ParseResult
    attr_reader :source, :path, :prism_result, :root, :diagnostics, :encoding

    def initialize(source, path, prism_result)
      @source = source
      @path = path
      @prism_result = prism_result
      @root = prism_result.value
      @diagnostics = build_diagnostics(prism_result)
      @encoding = prism_result.encoding
    end

    def success?
      @diagnostics.none? { |d| d[:severity] == :error }
    end

    def errors
      @diagnostics.select { |d| d[:severity] == :error }
    end

    def warnings
      @diagnostics.select { |d| d[:severity] == :warning }
    end

    private

    def build_diagnostics(prism_result)
      prism_result.errors.map do |error|
        location = error.location
        {
          severity: :error,
          message: error.message,
          path: @path,
          start_offset: location.start_offset,
          end_offset: location.end_offset,
          start_line: location.start_line,
          start_column: location.start_column,
          end_line: location.end_line,
          end_column: location.end_column
        }
      end + prism_result.warnings.map do |warning|
        location = warning.location
        {
          severity: :warning,
          message: warning.message,
          path: @path,
          start_offset: location.start_offset,
          end_offset: location.end_offset,
          start_line: location.start_line,
          start_column: location.start_column,
          end_line: location.end_line,
          end_column: location.end_column
        }
      end
    end
  end
end
