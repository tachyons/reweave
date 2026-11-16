# frozen_string_literal: true

module Reweave
  module Visitor
    class Cursor
      attr_reader :node, :parent_node, :index, :path

      def initialize(node, parent: nil, index: nil, path: [])
        @node = node
        @parent_node = parent
        @index = index
        @path = path
      end

      def parent(n = nil)
        return @parent_node if n.nil?
        current = @parent_node
        n.times { current = current&.parent_node }
        current
      end

      def parents
        return enum_for(:parents) unless block_given?
        current = @parent_node
        while current
          yield current
          current = current.parent_node
        end
      end

      def ancestors
        parents.to_a
      end

      def first_enclosing(*types)
        parents.find { |p| types.any? { |t| p.node.is_a?(t) } }
      end

      def find_ancestor(&block)
        parents.find(&block)
      end

      def siblings
        return [] unless @parent_node
        @parent_node.children.reject { |c| c.equal?(@node) }
      end

      def previous_sibling
        return nil unless @parent_node && @index && @index > 0
        @parent_node.children[@index - 1]
      end

      def next_sibling
        return nil unless @parent_node && @index && @index < @parent_node.children.size - 1
        @parent_node.children[@index + 1]
      end

      def root
        current = self
        current = current.parent_node while current.parent_node
        current
      end

      def replace(new_node)
        return unless @parent_node && @index
        @parent_node.children[@index] = new_node
      end

      def delete
        return unless @parent_node && @index
        @parent_node.children.delete_at(@index)
      end

      def inspect
        "#<Cursor node=#{@node.class} parent=#{@parent_node&.node&.class} index=#{@index}>"
      end
    end

    class CursorStack
      def initialize
        @stack = []
      end

      def push(cursor)
        @stack << cursor
      end

      def pop
        @stack.pop
      end

      def current
        @stack.last
      end

      def depth
        @stack.size
      end

      def ancestors
        @stack.map(&:node)
      end
    end
  end
end
