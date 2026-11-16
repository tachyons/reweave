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

      def visit(node)
        return unless node

        cursor = build_cursor(node)
        @cursor_stack.push(cursor)

        result = super

        @cursor_stack.pop
        result
      end

      def build_cursor(node)
        parent = @cursor_stack.current
        index = parent&.node&.child_nodes&.index(node)
        path = @cursor_stack.ancestors + [node]
        Cursor.new(node, parent: parent, index: index, path: path)
      end

      def cursor
        @cursor_stack.current
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
    end
  end
end
