# frozen_string_literal: true

require_relative "symbol"

module Reweave
  module Semantic
    # Index of all symbols (methods and constants) across a project.
    #
    # Methods are indexed by both instance and class method keys:
    #   - "Namespace#method_name" for instance methods
    #   - "Namespace.method_name" for class (singleton) methods
    #
    # Constants are indexed by their full qualified name:
    #   - "User" for top-level constants
    #   - "Admin::BaseController" for nested constants
    class SymbolTable
      def initialize
        @instance_methods = {} # "Namespace#method_name" => Symbol
        @class_methods = {}    # "Namespace.method_name" => Symbol
        @constants = {}        # "ConstantName" => Symbol
      end

      # Add a method definition to the table.
      def add_method(name, namespace, file_path, line, column, source, instance_method: true)
        key = build_method_key(name, namespace, instance_method: instance_method)
        symbol = Symbol.new(
          name: name,
          kind: :method,
          file_path: file_path,
          line: line,
          column: column,
          namespace: namespace,
          source: source
        )
        if instance_method
          @instance_methods[key] = symbol
        else
          @class_methods[key] = symbol
        end
        symbol
      end

      # Add a constant definition to the table.
      def add_constant(name, file_path, line, column, source, namespace: nil)
        full_name = namespace ? "#{namespace}::#{name}" : name.to_s
        symbol = Symbol.new(
          name: name,
          kind: :constant,
          file_path: file_path,
          line: line,
          column: column,
          namespace: namespace,
          source: source
        )
        @constants[full_name] = symbol
        symbol
      end

      # Resolve an instance method call: "namespace.method_name" or "namespace#method_name"
      def resolve_method(name, namespace = nil)
        key = build_method_key(name, namespace, instance_method: true)
        @instance_methods[key] || @class_methods[build_method_key(name, namespace, instance_method: false)]
      end

      # Resolve a constant by its (possibly qualified) name.
      def resolve_constant(name)
        @constants[name.to_s]
      end

      # All symbols of a given kind.
      def symbols(kind: nil)
        if kind
          all_symbols.select { |s| s.kind == kind }
        else
          all_symbols
        end
      end

      def size
        @instance_methods.size + @class_methods.size + @constants.size
      end

      def empty?
        size.zero?
      end

      private

      def all_symbols
        @instance_methods.values + @class_methods.values + @constants.values
      end

      def build_method_key(name, namespace, instance_method:)
        ns = namespace || "Object"
        separator = instance_method ? "#" : "."
        "#{ns}#{separator}#{name}"
      end
    end
  end
end
