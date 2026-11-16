# frozen_string_literal: true

require_relative "symbol_table"
require_relative "../../reweave/visitor/visitor"

module Reweave
  module Semantic
    # Walks a single source file's AST and collects method and constant
    # definitions into a SymbolTable. Tracks the current class/module
    # namespace so symbols are indexed with their proper scope.
    class SymbolCollector < Reweave::Visitor::Base
      def initialize(symbol_table, file_path, source: nil)
        super(nil, nil)
        @symbol_table = symbol_table
        @file_path = file_path
        @source = source || File.read(file_path, encoding: "bom|utf-8")
        @namespace_stack = []
      end

      # Collect symbols from a source file's AST root node.
      def run(root_node)
        traverse(root_node)
        @symbol_table
      end

      # Enter a class definition: record the constant and push namespace.
      def visit_class_node(node)
        const_name = constant_full_name(node.constant_path)
        namespace = current_namespace
        full_name = namespace ? "#{namespace}::#{const_name}" : const_name

        # Record the class itself as a constant
        @symbol_table.add_constant(
          const_name.to_sym,
          @file_path,
          node.location.start_line,
          node.location.start_column,
          source_for(node),
          namespace: namespace
        )

        @namespace_stack.push(full_name)
        visit_child_nodes(node) # traverse body
        @namespace_stack.pop
      end

      # Enter a module definition: record the constant and push namespace.
      def visit_module_node(node)
        const_name = constant_full_name(node.constant_path)
        namespace = current_namespace
        full_name = namespace ? "#{namespace}::#{const_name}" : const_name

        @symbol_table.add_constant(
          const_name.to_sym,
          @file_path,
          node.location.start_line,
          node.location.start_column,
          source_for(node),
          namespace: namespace
        )

        @namespace_stack.push(full_name)
        visit_child_nodes(node) # traverse body
        @namespace_stack.pop
      end

      # Enter a method definition: record instance or class method.
      def visit_def_node(node)
        method_name = node.name
        namespace = current_namespace || "Object"

        if node.receiver.nil?
          # Instance method: def foo; end
          @symbol_table.add_method(
            method_name, namespace, @file_path,
            node.location.start_line, node.location.start_column,
            source_for(node), instance_method: true
          )
        elsif node.receiver.is_a?(Prism::SelfNode)
          # Class method: def self.foo; end
          @symbol_table.add_method(
            method_name, namespace, @file_path,
            node.location.start_line, node.location.start_column,
            source_for(node), instance_method: false
          )
        elsif node.receiver.is_a?(Prism::ConstantReadNode)
          # Class method on a constant: def User.foo; end
          const_ns = node.receiver.name.to_s
          @symbol_table.add_method(
            method_name, const_ns, @file_path,
            node.location.start_line, node.location.start_column,
            source_for(node), instance_method: false
          )
        end

        visit_child_nodes(node) # traverse body
      end

      # Constant assignment: FOO = value
      def visit_constant_write_node(node)
        namespace = current_namespace
        @symbol_table.add_constant(
          node.name,
          @file_path,
          node.location.start_line,
          node.location.start_column,
          source_for(node),
          namespace: namespace
        )
        visit_child_nodes(node)
      end

      # Namespaced constant assignment: Foo::BAR = value
      def visit_constant_path_write_node(node)
        const_name = constant_full_name(node.target)
        namespace = current_namespace
        full_name = namespace ? "#{namespace}::#{const_name}" : const_name

        @symbol_table.add_constant(
          node.name,
          @file_path,
          node.location.start_line,
          node.location.start_column,
          source_for(node),
          namespace: full_name
        )
        visit_child_nodes(node)
      end

      private

      def current_namespace
        @namespace_stack.last
      end

      def source_for(node)
        loc = node.location
        @source[loc.start_offset...loc.end_offset]
      end

      # Convert a Prism constant path node to its full name string.
      #   ConstantReadNode(name: :User)          -> "User"
      #   ConstantPathNode(parent: :Foo, name: :Bar) -> "Foo::Bar"
      def constant_full_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          parent_name = constant_full_name(node.parent)
          "#{parent_name}::#{node.name}"
        when Prism::ConstantPathWriteNode
          constant_full_name(node.target)
        else
          node.name.to_s
        end
      end
    end
  end
end
