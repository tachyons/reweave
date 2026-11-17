# frozen_string_literal: true

require "prism"

module Reweave
  module AST
    # Wrapper around Prism nodes providing a clean, declarative API
    # for recipe authors. Hides Prism internals and provides
    # transformation-friendly methods.
    class Node
      attr_reader :prism_node, :source, :source_file

      def initialize(prism_node, source: nil, source_file: nil)
        @prism_node = prism_node
        @source = source
        @source_file = source_file
      end

      # Returns the Prism node type as a symbol (e.g., :call, :def, :class)
      def type
        @prism_node.class.name.split("::").last.sub("Node", "").gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
      end

      # Check if this is a specific node type
      def call? = @prism_node.is_a?(Prism::CallNode)
      def def? = @prism_node.is_a?(Prism::DefNode)
      def class? = @prism_node.is_a?(Prism::ClassNode)
      def module? = @prism_node.is_a?(Prism::ModuleNode)
      def constant? = @prism_node.is_a?(Prism::ConstantReadNode)
      def constant_path? = @prism_node.is_a?(Prism::ConstantPathNode)
      def symbol? = @prism_node.is_a?(Prism::SymbolNode)
      def string? = @prism_node.is_a?(Prism::StringNode)
      def integer? = @prism_node.is_a?(Prism::IntegerNode)
      def array? = @prism_node.is_a?(Prism::ArrayNode)
      def hash? = @prism_node.is_a?(Prism::HashNode)
      def block? = @prism_node.is_a?(Prism::BlockNode)
      def lambda? = @prism_node.is_a?(Prism::LambdaNode)

      # For call nodes - define methods that work on any node but only return meaningful values for call nodes
      def method_name
        @prism_node.name if @prism_node.respond_to?(:name)
      end

      def receiver
        if @prism_node.respond_to?(:receiver) && @prism_node.receiver
          self.class.new(@prism_node.receiver, source: @source, source_file: @source_file)
        end
      end

      def receiver_name
        receiver&.constant_name || receiver&.method_name || receiver&.source
      end

      def args
        if @prism_node.respond_to?(:arguments) && @prism_node.arguments
          @prism_node.arguments.arguments&.map { |arg| self.class.new(arg, source: @source, source_file: @source_file) } || []
        else
          []
        end
      end

      def kwargs
        if @prism_node.respond_to?(:arguments) && @prism_node.arguments
          @prism_node.arguments.arguments&.select { |a| a.is_a?(Prism::AssocNode) || a.is_a?(Prism::KeywordHashNode) }&.flat_map do |a|
            if a.is_a?(Prism::AssocNode)
              [{key: a.key.value.to_s.sub(/^:/, ""), value: self.class.new(a.value, source: @source, source_file: @source_file)}]
            else
              a.elements.map { |e| {key: e.key.value.to_s.sub(/^:/, ""), value: self.class.new(e.value, source: @source, source_file: @source_file)} }
            end
          end || []
        else
          []
        end
      end

      def block
        if @prism_node.respond_to?(:block) && @prism_node.block
          self.class.new(@prism_node.block, source: @source, source_file: @source_file)
        end
      end

      # For def nodes
      if @prism_node.is_a?(Prism::DefNode)
        def method_name
          @prism_node.name
        end

        def params
          return [] unless @prism_node.parameters
          @prism_node.parameters.requireds.map { |p| p.name.to_s }
        end

        def body
          if @prism_node.body
            self.class.new(@prism_node.body, source: @source, source_file: @source_file)
          end
        end
      end

      # For class/module nodes
      if @prism_node.is_a?(Prism::ClassNode) || @prism_node.is_a?(Prism::ModuleNode)
        def constant_name
          if @prism_node.constant_path.is_a?(Prism::ConstantReadNode)
            @prism_node.constant_path.name.to_s
          elsif @prism_node.constant_path.is_a?(Prism::ConstantPathNode)
            parent = self.class.new(@prism_node.constant_path.parent, source: @source, source_file: @source_file)
            "#{parent.constant_name}::#{@prism_node.constant_path.name}"
          end
        end

        def superclass
          if @prism_node.superclass
            self.class.new(@prism_node.superclass, source: @source, source_file: @source_file)
          end
        end

        def body
          if @prism_node.body
            self.class.new(@prism_node.body, source: @source, source_file: @source_file)
          end
        end
      end

      # For constant nodes - define method that works on any node
      def constant_name
        @prism_node.name.to_s if @prism_node.respond_to?(:name)
      end

      # For symbol nodes
      if @prism_node.is_a?(Prism::SymbolNode)
        def value
          @prism_node.value
        end
      end

      # For string nodes
      if @prism_node.is_a?(Prism::StringNode)
        def value
          @prism_node.unescaped
        end
      end

      # For integer nodes
      if @prism_node.is_a?(Prism::IntegerNode)
        def value
          @prism_node.value
        end
      end

      # For block nodes
      if @prism_node.is_a?(Prism::BlockNode)
        def parameters
          if @prism_node.parameters
            params_node = @prism_node.parameters.parameters
            params_node.requireds.map { |p| p.name.to_s }
          else
            []
          end
        end

        def body
          if @prism_node.body
            self.class.new(@prism_node.body, source: @source, source_file: @source_file)
          end
        end
      end

      # For lambda nodes
      if @prism_node.is_a?(Prism::LambdaNode)
        def parameters
          if @prism_node.parameters
            params_node = @prism_node.parameters.parameters
            params_node.requireds.map { |p| p.name.to_s }
          else
            []
          end
        end

        def body
          if @prism_node.body
            self.class.new(@prism_node.body, source: @source, source_file: @source_file)
          end
        end
      end

      # Generic source extraction
      def source
        return @source if @source
        return @source_file.source[@prism_node.location.start_offset...@prism_node.location.end_offset] if @source_file && @prism_node.respond_to?(:location)
        ""
      end

      def start_line
        @prism_node.location.start_line if @prism_node.respond_to?(:location)
      end

      def start_column
        @prism_node.location.start_column if @prism_node.respond_to?(:location)
      end

      def location
        @prism_node.location
      end

      # Replace this node's source with new text
      def replace(new_source)
        @source_file&.replace(@prism_node, new_source)
      end

      # Replace a specific location
      def replace_location(location, new_source)
        @source_file&.replace_location(location, new_source)
      end
    end
  end
end
