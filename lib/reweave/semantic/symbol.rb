# frozen_string_literal: true

module Reweave
  module Semantic
    # Represents a resolved symbol (method or constant) in the codebase.
    class Symbol
      attr_reader :name, :kind, :file_path, :line, :column, :namespace, :source

      # @param name [Symbol] the symbol name
      # @param kind [Symbol] :method or :constant
      # @param file_path [String] path to the file where the symbol is defined
      # @param line [Integer] line number (1-based)
      # @param column [Integer] column number (0-based)
      # @param namespace [String, nil] enclosing class/module namespace (e.g., "User", "Admin::BaseController")
      # @param source [String, nil] source text of the definition
      def initialize(name:, kind:, file_path:, line:, column:, namespace: nil, source: nil)
        @name = name
        @kind = kind
        @file_path = file_path
        @line = line
        @column = column
        @namespace = namespace
        @source = source
      end

      def method?
        kind == :method
      end

      def constant?
        kind == :constant
      end

      def to_s
        "#<Reweave::Semantic::Symbol #{kind}=#{name} #{file_path}:#{line}>"
      end
      alias_method :inspect, :to_s
    end
  end
end
