# frozen_string_literal: true

require "prism"
require_relative "cursor"

module Reweave
  module Visitor
    class Base < Prism::Visitor
      attr_reader :context, :edits, :cursor_stack, :source_file

      def initialize(context, source_file)
        super()
        @context = context
        @source_file = source_file
        @edits = Editing::EditSet.new
        @cursor_stack = CursorStack.new
      end

      def source
        @source_file.source
      end

      def source_id
        @source_file.identity
      end

      def cursor
        @cursor_stack.current
      end

      def traverse(node)
        return unless node

        cursor = build_cursor(node)
        @cursor_stack.push(cursor)

        visit_node(node)

        @cursor_stack.pop
      end

      def visit_node(node)
        method_name = "visit_#{node.class.name.split("::").last.gsub("Node", "").gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase}_node"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          visit_child_nodes(node)
        end
      end

      def visit_child_nodes(node)
        node.each_child_node { |child| traverse(child) }
      end

      def build_cursor(node)
        parent = @cursor_stack.current
        index = parent&.node&.child_nodes&.index(node)
        path = @cursor_stack.ancestors + [node]
        Cursor.new(node, parent: parent, index: index, path: path)
      end

      # Override Prism's default visit methods to use our traversal
      Prism::Visitor.instance_methods(false).grep(/^visit_.*_node$/).each do |method|
        define_method(method) do |node|
          visit_child_nodes(node)
        end
      end

      def replace(node, replacement)
        loc = node.location
        @edits.add(Editing.replace(source_id, loc.start_offset, loc.end_offset, replacement, recipe_name))
      end

      def replace_location(location, replacement)
        @edits.add(Editing.replace(source_id, location.start_offset, location.end_offset, replacement, recipe_name))
      end

      def insert_before(node, text)
        loc = node.location
        @edits.add(Editing.insert(source_id, loc.start_offset, text, recipe_name))
      end

      def insert_after(node, text)
        loc = node.location
        @edits.add(Editing.insert(source_id, loc.end_offset, text, recipe_name))
      end

      def delete(node)
        loc = node.location
        @edits.add(Editing.delete(source_id, loc.start_offset, loc.end_offset, recipe_name))
      end

      def recipe_name
        self.class.name
      end

      # File operations for creating, deleting, renaming files
      def create_file(path, contents)
        @file_operations ||= []
        @file_operations_set ||= Set.new
        key = [:create, path]
        @file_operations << {type: :create, path: path, contents: contents} unless @file_operations_set.include?(key)
        @file_operations_set.add(key)
      end

      def delete_file(path)
        @file_operations ||= []
        @file_operations_set ||= Set.new
        key = [:delete, path]
        @file_operations << {type: :delete, path: path} unless @file_operations_set.include?(key)
        @file_operations_set.add(key)
      end

      def rename_file(old_path, new_path)
        @file_operations ||= []
        @file_operations_set ||= Set.new
        key = [:rename, old_path, new_path]
        @file_operations << {type: :rename, old_path: old_path, new_path: new_path} unless @file_operations_set.include?(key)
        @file_operations_set.add(key)
      end

      def file_operations
        @file_operations || []
      end
    end
  end
end
