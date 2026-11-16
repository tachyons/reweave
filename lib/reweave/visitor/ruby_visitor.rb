# frozen_string_literal: true

require_relative "visitor"

module Reweave
  module Visitor
    class RubyVisitor < Base
      # Class/Module definitions
      def visit_class_node(node)
        super
      end

      def visit_module_node(node)
        super
      end

      def visit_singleton_class_node(node)
        super
      end

      # Method definitions
      def visit_def_node(node)
        super
      end

      def visit_defs_node(node)
        super
      end

      # Method calls
      def visit_call_node(node)
        super
      end

      def visit_call_operator_write_node(node)
        super
      end

      def visit_operator_write_node(node)
        super
      end

      def visit_or_write_node(node)
        super
      end

      def visit_and_write_node(node)
        super
      end

      # Blocks
      def visit_block_node(node)
        super
      end

      def visit_do_block_node(node)
        super
      end

      def visit_brace_block_node(node)
        super
      end

      def visit_block_parameters_node(node)
        super
      end

      # Control flow
      def visit_if_node(node)
        super
      end

      def visit_unless_node(node)
        super
      end

      def visit_case_node(node)
        super
      end

      def visit_when_node(node)
        super
      end

      def visit_while_node(node)
        super
      end

      def visit_until_node(node)
        super
      end

      def visit_for_node(node)
        super
      end

      def visit_break_node(node)
        super
      end

      def visit_next_node(node)
        super
      end

      def visit_redo_node(node)
        super
      end

      def visit_retry_node(node)
        super
      end

      def visit_return_node(node)
        super
      end

      # Variables and constants
      def visit_constant_read_node(node)
        super
      end

      def visit_constant_path_node(node)
        super
      end

      def visit_constant_write_node(node)
        super
      end

      def visit_constant_path_write_node(node)
        super
      end

      def visit_constant_target_node(node)
        super
      end

      def visit_local_variable_read_node(node)
        super
      end

      def visit_local_variable_write_node(node)
        super
      end

      def visit_local_variable_target_node(node)
        super
      end

      def visit_instance_variable_read_node(node)
        super
      end

      def visit_instance_variable_write_node(node)
        super
      end

      def visit_instance_variable_target_node(node)
        super
      end

      def visit_class_variable_read_node(node)
        super
      end

      def visit_class_variable_write_node(node)
        super
      end

      def visit_class_variable_target_node(node)
        super
      end

      def visit_global_variable_read_node(node)
        super
      end

      def visit_global_variable_write_node(node)
        super
      end

      def visit_global_variable_target_node(node)
        super
      end

      # Literals
      def visit_string_node(node)
        super
      end

      def visit_interpolated_string_node(node)
        super
      end

      def visit_symbol_node(node)
        super
      end

      def visit_integer_node(node)
        super
      end

      def visit_float_node(node)
        super
      end

      def visit_rational_node(node)
        super
      end

      def visit_imaginary_node(node)
        super
      end

      def visit_array_node(node)
        super
      end

      def visit_hash_node(node)
        super
      end

      def visit_keyword_hash_node(node)
        super
      end

      def visit_assoc_node(node)
        super
      end

      def visit_range_node(node)
        super
      end

      def visit_regexp_node(node)
        super
      end

      def visit_interpolated_regexp_node(node)
        super
      end

      # True/False/Nil/Self
      def visit_true_node(node)
        super
      end

      def visit_false_node(node)
        super
      end

      def visit_nil_node(node)
        super
      end

      def visit_self_node(node)
        super
      end

      # Aliases and undef
      def visit_alias_node(node)
        super
      end

      def visit_undef_node(node)
        super
      end

      # Super and yield
      def visit_super_node(node)
        super
      end

      def visit_zsuper_node(node)
        super
      end

      def visit_yield_node(node)
        super
      end

      # Arguments
      def visit_arguments_node(node)
        super
      end

      def visit_keyword_rest_node(node)
        super
      end

      def visit_block_local_variable_node(node)
        super
      end

      def visit_numbered_parameters_node(node)
        super
      end

      # Rescue/Ensure
      def visit_rescue_node(node)
        super
      end

      def visit_ensure_node(node)
        super
      end

      def visit_resbody_node(node)
        super
      end

      # Lambda/Proc
      def visit_lambda_node(node)
        super
      end

      # Match
      def visit_match_predicate_node(node)
        super
      end

      def visit_match_write_node(node)
        super
      end

      # Forwarding
      def visit_forwarding_super_node(node)
        super
      end

      def visit_forwarding_args_node(node)
        super
      end

      # Helpers for matching
      def match_call?(node, receiver: nil, method: nil, **kwargs)
        return false unless node.is_a?(Prism::CallNode)
        return false if receiver && node.receiver&.slice != receiver
        return false if method && node.name != method
        kwargs.all? { |k, v| node.respond_to?(k) && node.public_send(k) == v }
      end

      def match_constant?(node, name: nil, **kwargs)
        return false unless node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)
        return false if name && node.slice != name.to_s
        kwargs.all? { |k, v| node.respond_to?(k) && node.public_send(k) == v }
      end

      def match_method_def?(node, name: nil, **kwargs)
        return false unless node.is_a?(Prism::DefNode)
        return false if name && node.name != name
        kwargs.all? { |k, v| node.respond_to?(k) && node.public_send(k) == v }
      end

      def extract_receiver_name(node)
        return nil unless node.receiver
        case node.receiver
        when Prism::ConstantReadNode, Prism::ConstantPathNode
          node.receiver.slice
        when Prism::SelfNode
          "self"
        when Prism::CallNode
          extract_receiver_name(node.receiver)
        else
          node.receiver.slice
        end
      end

      def extract_method_name(node)
        node.name
      end

      def extract_arguments(node)
        return [] unless node.arguments
        node.arguments.arguments || []
      end

      def extract_keyword_arguments(node)
        return {} unless node.arguments
        kwargs = []
        node.arguments.arguments.each do |arg|
          if arg.is_a?(Prism::AssocNode)
            kwargs << arg
          elsif arg.is_a?(Prism::KeywordHashNode)
            kwargs.concat(arg.elements)
          end
        end
        kwargs.to_h { |a| [a.key.slice.sub(/:$/, "").to_sym, a.value] }
      end

      def source_for(node)
        loc = node.location
        @source_file.source[loc.start_offset...loc.end_offset]
      end
    end
  end
end
