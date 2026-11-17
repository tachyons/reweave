# frozen_string_literal: true

require_relative "recipe"
require_relative "../ast/node"

module Reweave
  # Declarative DSL for writing recipes without Prism internals
  module DSL
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Define a transformation for call nodes
      #   transform_call(method: :find, receiver: "User") { |node| node.replace("User.all") }
      def transform_call(method: nil, receiver: nil, args: nil, &block)
        @call_transforms ||= []
        @call_transforms << {method: method, receiver: receiver, args: args, block: block}
      end

      # Define a transformation for def nodes
      #   transform_def(name: :initialize) { |node| node.replace(...) }
      def transform_def(name: nil, &block)
        @def_transforms ||= []
        @def_transforms << {name: name, block: block}
      end

      # Define a transformation for class nodes
      def transform_class(name: nil, &block)
        @class_transforms ||= []
        @class_transforms << {name: name, block: block}
      end

      # Define a transformation for constant nodes
      def transform_constant(name: nil, &block)
        @constant_transforms ||= []
        @constant_transforms << {name: name, block: block}
      end

      # Define a transformation for hash nodes
      def transform_hash(&block)
        @hash_transforms ||= []
        @hash_transforms << {block: block}
      end

      # Define a transformation for lambda nodes
      def transform_lambda(&block)
        @lambda_transforms ||= []
        @lambda_transforms << {block: block}
      end

      # Define a transformation for block parameter nodes
      def transform_block_params(&block)
        @block_params_transforms ||= []
        @block_params_transforms << {block: block}
      end

      # Generic pattern matching transform
      def transform(pattern, &block)
        @generic_transforms ||= []
        @generic_transforms << {pattern: pattern, block: block}
      end

      def call_transforms
        @call_transforms || []
      end

      def def_transforms
        @def_transforms || []
      end

      def class_transforms
        @class_transforms || []
      end

      def constant_transforms
        @constant_transforms || []
      end

      def hash_transforms
        @hash_transforms || []
      end

      def lambda_transforms
        @lambda_transforms || []
      end

      def block_params_transforms
        @block_params_transforms || []
      end

      def generic_transforms
        @generic_transforms || []
      end

      # Helper to match receiver by name pattern
      def receiver_matches?(node, pattern)
        return true unless pattern
        recv = node.receiver
        return false unless recv
        case pattern
        when String
          recv.receiver_name == pattern || recv.constant_name == pattern
        when Regexp
          (recv.receiver_name || recv.constant_name || "").match?(pattern)
        when Proc
          # Instance-aware proc: call with instance, use result as pattern
          if pattern.arity == 1
            resolved = pattern.call(@recipe_class)
            # Don't recurse if result is also a proc (node-level matcher)
            if resolved.is_a?(Proc)
              resolved.call(recv)
            else
              receiver_matches?(node, resolved)
            end
          else
            pattern.call(recv)
          end
        else
          false
        end
      end

      # Helper to match method name
      def method_matches?(node, pattern)
        return true unless pattern
        case pattern
        when Symbol, String
          node.method_name == pattern
        when Regexp
          node.method_name.to_s.match?(pattern)
        when Proc
          if pattern.arity == 1
            resolved = pattern.call(@recipe_class)
            if resolved.is_a?(Proc)
              resolved.call(node.method_name)
            else
              method_matches?(node, resolved)
            end
          else
            pattern.call(node.method_name)
          end
        else
          false
        end
      end

      # Helper to match args
      def args_match?(node, pattern)
        return true unless pattern
        case pattern
        when Integer
          node.args.size == pattern
        when Range
          pattern.cover?(node.args.size)
        when Array
          pattern.map { |p| arg_match?(node, p) }
        when Hash
          pattern.all? { |k, v| kwarg_match?(node, k, v) }
        when Proc
          if pattern.arity == 1
            resolved = pattern.call(@recipe_class)
            if resolved.is_a?(Proc)
              resolved.call(node.args)
            else
              case resolved
              when true, false
                resolved
              else
                args_match?(node, resolved)
              end
            end
          else
            pattern.call(node.args)
          end
        else
          false
        end
      end

      def arg_match?(node, pattern)
        case pattern
        when :symbol
          node.first&.symbol?
        when :string
          node.first&.string?
        when Symbol, String
          node.first&.value == pattern
        else
          false
        end
      end

      def kwarg_match?(node, key, pattern)
        kw = node.kwargs.find { |k| k[:key] == key.to_s }
        return false unless kw
        case pattern
        when Symbol, String
          kw[:value].value == pattern
        when Regexp
          kw[:value].value.to_s.match?(pattern)
        when Proc
          pattern.call(kw[:value].value)
        else
          true
        end
      end
    end

    # Instance method to apply transforms during traversal
    def apply_transforms(node, source_file)
      ast_node = AST::Node.new(node, source: source_file.source, source_file: source_file)

      # Apply call transforms
      self.class.call_transforms.each do |transform|
        if ast_node.call? &&
            self.class.method_matches?(ast_node, transform[:method]) &&
            self.class.receiver_matches?(ast_node, transform[:receiver]) &&
            self.class.args_match?(ast_node, transform[:args])
          transform[:block].call(ast_node)
        end
      end

      # Apply def transforms
      if ast_node.def?
        self.class.def_transforms.each do |transform|
          if self.class.method_matches?(ast_node, transform[:name])
            transform[:block].call(ast_node)
          end
        end
      end

      # Apply class transforms
      if ast_node.class?
        self.class.class_transforms.each do |transform|
          if self.class.method_matches?(ast_node, transform[:name])
            transform[:block].call(ast_node)
          end
        end
      end

      # Apply constant transforms
      if ast_node.constant?
        self.class.constant_transforms.each do |transform|
          if self.class.method_matches?(ast_node, transform[:name])
            transform[:block].call(ast_node)
          end
        end
      end

      # Apply generic transforms
      self.class.generic_transforms.each do |transform|
        # Pattern matching would go here
      end
    end
  end
end
