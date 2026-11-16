# frozen_string_literal: true

require_relative "ruby_visitor"

module Reweave
  module Visitor
    # Provides common recipe operations as reusable methods
    module RecipeHelpers
      # Replace a method call's name (e.g., update_attributes -> update)
      def replace_method_name(node, new_name)
        return unless node.is_a?(Prism::CallNode) && node.message_loc
        replace_location(node.message_loc, new_name.to_s)
      end

      # Replace the entire call node with a new expression
      def replace_call(node, new_source)
        replace(node, new_source)
      end

      # Replace a specific argument in a call
      def replace_argument(node, arg_index, new_source)
        args = extract_arguments(node)
        return unless args[arg_index]
        replace(args[arg_index], new_source)
      end

      # Replace the first argument if it matches a value
      def replace_first_arg_if(node, old_value, new_source)
        args = extract_arguments(node)
        return unless args.first
        arg = args.first
        if values_equal?(arg, old_value)
          replace(arg, new_source)
        end
      end

      # Check if a node's value equals a given value (handles SymbolNode, StringNode, etc.)
      def values_equal?(node, expected)
        case node
        when Prism::SymbolNode
          node.value == expected.to_s
        when Prism::StringNode
          node.unescaped == expected.to_s
        when Prism::IntegerNode
          node.value == expected
        else
          false
        end
      end

      # Match a config setter: config.xxx.yyy = value
      # path_parts is the receiver chain from outermost to innermost (e.g., [:config, :active_job])
      # method is the setter method name (e.g., :queue_adapter=)
      def match_config_setter?(node, *path_parts, method: nil)
        # Normalize path_parts to symbols for comparison with chain (which uses Symbol names)
        path_parts = path_parts.map(&:to_sym)

        return false unless match_call?(node, method: method || :"#{path_parts.last}=")

        # Walk inward through call nodes, collecting names (innermost-first)
        receiver = node.receiver
        chain = []
        while receiver.is_a?(Prism::CallNode)
          chain << receiver.name
          receiver = receiver.receiver
        end

        # After the chain, receiver must be :config constant (or nil/self)
        base_ok = receiver.nil? || receiver.is_a?(Prism::SelfNode) ||
          (receiver.is_a?(Prism::ConstantReadNode) && receiver.name == :config)
        return false unless base_ok

        # Build full path: [:config] + chain reversed (outermost-first)
        full_path = if receiver.is_a?(Prism::ConstantReadNode) && receiver.name == :config
          [:config] + chain.reverse
        else
          chain.reverse
        end

        full_path == path_parts
      end

      # Match a call with specific receiver chain and method
      def match_call_chain?(node, *chain, method: nil)
        return false unless match_call?(node, method: method)
        receiver = node.receiver
        chain.reverse.each do |part|
          return false unless receiver&.is_a?(Prism::CallNode) && receiver.name == part
          receiver = receiver.receiver
        end
        receiver.nil? || receiver.is_a?(Prism::SelfNode) || (receiver.is_a?(Prism::ConstantReadNode) && receiver.name == :config)
      end

      # Replace method call with method call on same receiver: receiver.old_method(args) -> receiver.new_method(args)
      def replace_method_on_receiver(node, new_method_name)
        receiver = node.receiver
        args = extract_arguments(node)
        return unless receiver
        arg_sources = args.map { |a| source_for(a) }.join(", ")
        replace(node, "#{source_for(receiver)}.#{new_method_name}(#{arg_sources})")
      end

      # Replace method call with new receiver.method: receiver.old_method(args) -> new_receiver.new_method(args)
      def replace_receiver_and_method(node, new_receiver, new_method_name)
        args = extract_arguments(node)
        arg_sources = args.map { |a| source_for(a) }.join(", ")
        replace(node, "#{new_receiver}.#{new_method_name}(#{arg_sources})")
      end

      # Convert hash rocket to symbol key syntax in place
      def convert_hash_rocket_to_symbol_key(node)
        return unless node.is_a?(Prism::AssocNode)
        return unless node.key.is_a?(Prism::SymbolNode)
        return unless node.operator_loc&.slice == "=>"

        key_loc = node.key.location
        operator_loc = node.operator_loc
        new_key = key_loc.slice.sub(/^:/, "") + ":"
        start_offset = key_loc.start_offset
        end_offset = operator_loc.end_offset
        @edits.add(Editing.replace(source_id, start_offset, end_offset, new_key, recipe_name))
      end

      # Check if a node is a simple method call (no arguments, no block)
      def simple_call?(node, method: nil)
        return false unless node.is_a?(Prism::CallNode)
        return false if method && node.name != method
        extract_arguments(node).empty? && node.block.nil?
      end

      # Check if a node is a method call with specific argument count
      def call_with_args?(node, count, method: nil)
        return false unless node.is_a?(Prism::CallNode)
        return false if method && node.name != method
        extract_arguments(node).size == count
      end

      # Get the first argument as a specific type
      def first_arg(node, *types)
        args = extract_arguments(node)
        return nil if args.empty?
        arg = args.first
        return arg if types.empty? || types.any? { |t| arg.is_a?(t) }
        nil
      end

      # Get keyword argument value by key
      def keyword_arg(node, key)
        kwargs = extract_keyword_arguments(node)
        kwargs[key]
      end

      # Replace keyword argument value
      def replace_keyword_arg(node, key, new_source)
        kwargs = extract_keyword_arguments(node)
        return unless kwargs[key]
        replace(kwargs[key], new_source)
      end

      # Check if a symbol node matches a name
      def symbol_node?(node, name)
        node.is_a?(Prism::SymbolNode) && node.value == name.to_s
      end

      # Check if a string node matches a value
      def string_node?(node, value)
        node.is_a?(Prism::StringNode) && node.unescaped == value
      end

      # Replace a node's source with a new method call on the same receiver
      def replace_with_method_call(node, method_name, *extra_args)
        receiver = node.receiver
        return unless receiver
        args = extract_arguments(node)
        all_args = args + extra_args
        arg_sources = all_args.map { |a| source_for(a) }.join(", ")
        replace(node, "#{source_for(receiver)}.#{method_name}(#{arg_sources})")
      end

      # Common pattern: replace config.setter = :old_value with :new_value
      # config_path is the receiver chain (e.g., [:config, :active_job])
      # method is the setter method name (e.g., :queue_adapter=)
      def replace_config_value(node, config_path, old_values, new_value, method: nil)
        return unless match_config_setter?(node, *config_path, method: method)
        args = extract_arguments(node)
        return if args.empty?

        arg = args.first
        old_value_str = case arg
        when Prism::SymbolNode then arg.value
        when Prism::StringNode then arg.unescaped
        else return
        end

        return unless old_values.include?(old_value_str)

        replacement = case arg
        when Prism::SymbolNode then ":#{new_value}"
        when Prism::StringNode then "\"#{new_value}\""
        end
        replace(arg, replacement)
      end

      # Build a method call source string
      def build_call_source(receiver_source, method_name, *arg_sources)
        "#{receiver_source}.#{method_name}(#{arg_sources.join(", ")})"
      end

      # Check if we're in a config block (config.xxx = value)
      def in_config_block?(node)
        current = node
        while current
          if current.is_a?(Prism::CallNode) && current.receiver&.is_a?(Prism::ConstantReadNode) && current.receiver.name == :config
            return true
          end
          current = cursor&.parent_node
        end
        false
      end
    end
  end
end
