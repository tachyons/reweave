# frozen_string_literal: true

require_relative "type"
require_relative "../visitor/ruby_visitor"

module Reweave
  module Semantic
    # Collects and infers type information from the AST
    class TypeCollector < Reweave::Visitor::RubyVisitor
      def initialize(context, symbol_table, source_file)
        super(context, source_file)
        @symbol_table = symbol_table
        @type_table = TypeTable.new
        @local_variables = {}  # var_name => type
        @method_stack = []     # stack of { method_name, return_type, param_types }
        @class_stack = []      # stack of class/module context
      end

      def run(root_node)
        traverse(root_node)
        @type_table
      end

      # Visit class definition - track class hierarchy
      def visit_class_node(node)
        class_name = node.constant_path&.slice || node.name.to_s
        superclass = nil
        if node.superclass
          superclass_name = node.superclass.slice
          superclass = @symbol_table.resolve_constant(superclass_name)
          superclass = TypeFactory.class_type(superclass_name.to_sym) if superclass
        end

        class_type = TypeFactory.class_type(class_name.to_sym, superclass: superclass)
        @type_table.add_class(class_name, class_type)
        @class_stack.push(class_type)

        # Process body with class context
        visit_child_nodes(node)

        @class_stack.pop
        super
      end

      def visit_module_node(node)
        module_name = node.constant_path&.slice || node.name.to_s
        module_type = TypeFactory.module_type(module_name.to_s)
        @type_table.add_module(module_name, module_type)
        @class_stack.push(module_type)

        visit_child_nodes(node)

        @class_stack.pop
        super
      end

      # Visit method definition - track parameters and infer return type
      def visit_def_node(node)
        method_name = node.name.to_sym
        params = node.parameters
        param_types = {}

        if params
          params.requireds.each do |param|
            param_types[param.name.to_sym] = TypeFactory.unknown
          end
          params.optionals.each do |param|
            param_types[param.name.to_sym] = TypeFactory.unknown
          end
        end

        @method_stack.push({name: method_name, param_types: param_types, return_type: TypeFactory.unknown})

        # Infer types in method body
        if node.body
          traverse(node.body)
        end

        # Get inferred return type from the last expression or explicit return
        method_info = @method_stack.pop
        return_type = infer_return_type(node.body) || TypeFactory.unknown

        # Register method in current class context
        if @class_stack.any?
          current_class = @class_stack.last
          current_class.add_method(method_name, return_type, method_info[:param_types].values)
        end

        # Store method type in type table
        @type_table.add_method(method_name, param_types, return_type)

        super
      end

      # Visit method calls - infer types from receiver and arguments
      def visit_call_node(node)
        receiver = node.receiver
        method_name = node.name
        args = node.arguments&.arguments || []

        # Infer receiver type
        receiver_type = receiver ? infer_type(receiver) : TypeFactory.unknown

        # Infer argument types
        arg_types = args.map { |arg| infer_type(arg) }

        # Look up method signature from receiver type
        if receiver_type.class_type? && receiver_type.respond_to?(:methods)
          method_info = receiver_type.methods[method_name]
          if method_info
            # Check argument compatibility
            # TODO: More sophisticated type checking
          end
        end

        # Store call type info
        @type_table.add_call(node, receiver_type, method_name, arg_types)

        # Infer result type
        result_type = infer_call_result_type(receiver_type, method_name, arg_types)
        @type_table.set_node_type(node, result_type)

        super
      end

      # Local variable assignment - infer type from value
      def visit_local_variable_write_node(node)
        var_name = node.name.to_sym
        value_node = node.value
        type = value_node ? infer_type(value_node) : TypeFactory.unknown

        @local_variables[var_name] = type
        @type_table.set_variable_type(var_name, type)

        super
      end

      def visit_local_variable_read_node(node)
        var_name = node.name.to_sym
        type = @local_variables[var_name] || @type_table.variable_type(var_name)
        @type_table.set_node_type(node, type || TypeFactory.unknown)
        super
      end

      # Instance variable assignment
      def visit_instance_variable_write_node(node)
        var_name = node.name.to_sym
        type = node.value ? infer_type(node.value) : TypeFactory.unknown
        @type_table.set_ivar_type(var_name, type)
        super
      end

      # Constant assignment - track constant types
      def visit_constant_write_node(node)
        const_name = node.name.to_sym
        type = node.value ? infer_type(node.value) : TypeFactory.unknown
        @type_table.add_constant(const_name, type)
        super
      end

      def visit_constant_path_write_node(node)
        full_name = node.target.slice
        node.name.to_sym
        type = node.value ? infer_type(node.value) : TypeFactory.unknown
        @type_table.add_constant(full_name.to_sym, type)
        super
      end

      # Literal types
      def visit_integer_node(node)
        @type_table.set_node_type(node, TypeFactory::INTEGER)
        super
      end

      def visit_float_node(node)
        @type_table.set_node_type(node, TypeFactory::FLOAT)
        super
      end

      def visit_string_node(node)
        @type_table.set_node_type(node, TypeFactory::STRING)
        super
      end

      def visit_symbol_node(node)
        @type_table.set_node_type(node, TypeFactory::SYMBOL)
        super
      end

      def visit_true_node(node)
        @type_table.set_node_type(node, TypeFactory::TRUE_CLASS)
        super
      end

      def visit_false_node(node)
        @type_table.set_node_type(node, TypeFactory::FALSE_CLASS)
        super
      end

      def visit_nil_node(node)
        @type_table.set_node_type(node, TypeFactory::NIL_CLASS)
        super
      end

      def visit_array_node(node)
        element_types = node.elements.map { |elem| infer_type(elem) }
        # Create array type with element type union
        if element_types.uniq.size == 1
          element_types.first
        else
          TypeFactory.union(*element_types)
        end
        TypeFactory.class_type(:Array)
        # For now, use Array primitive
        @type_table.set_node_type(node, TypeFactory::ARRAY)
        super
      end

      def visit_hash_node(node)
        key_types = []
        value_types = []
        node.elements.each do |elem|
          if elem.is_a?(Prism::AssocNode)
            key_types << infer_type(elem.key)
            value_types << infer_type(elem.value)
          end
        end
        @type_table.set_node_type(node, TypeFactory::HASH)
        super
      end

      def visit_range_node(node)
        @type_table.set_node_type(node, TypeFactory::RANGE)
        super
      end

      def visit_regexp_node(node)
        @type_table.set_node_type(node, TypeFactory::REGEXP)
        super
      end

      def visit_self_node(node)
        # self type is the current class
        current_class = @class_stack.last
        type = current_class || TypeFactory.unknown
        @type_table.set_node_type(node, type)
        super
      end

      # Block parameters
      def visit_block_parameters_node(node)
        if node.parameters
          params = node.parameters
          params.requireds.each do |param|
            param_name = param.name.to_sym
            @local_variables[param_name] = TypeFactory.unknown
          end
        end
        super
      end

      # Accessors
      attr_reader :type_table, :local_variables

      private

      # Infer type of an expression node
      def infer_type(node)
        return TypeFactory.unknown unless node

        # Check if we already inferred this node's type
        cached = @type_table.node_type(node)
        return cached if cached

        case node
        when Prism::IntegerNode
          TypeFactory::INTEGER
        when Prism::FloatNode
          TypeFactory::FLOAT
        when Prism::StringNode
          TypeFactory::STRING
        when Prism::SymbolNode
          TypeFactory::SYMBOL
        when Prism::TrueNode
          TypeFactory::TRUE_CLASS
        when Prism::FalseNode
          TypeFactory::FALSE_CLASS
        when Prism::NilNode
          TypeFactory::NIL_CLASS
        when Prism::ArrayNode
          TypeFactory::ARRAY
        when Prism::HashNode
          TypeFactory::HASH
        when Prism::RangeNode
          TypeFactory::RANGE
        when Prism::RegularExpressionNode
          TypeFactory::REGEXP
        when Prism::SelfNode
          @class_stack.last || TypeFactory.unknown
        when Prism::LocalVariableReadNode
          node.name.to_sym
          @local_variables[node.name.to_sym] || @type_table.variable_type(node.name.to_sym) || TypeFactory.unknown
        when Prism::InstanceVariableReadNode
          @type_table.ivar_type(node.name.to_sym) || TypeFactory.unknown
        when Prism::ConstantReadNode
          @type_table.constant_type(node.name.to_sym) || TypeFactory.unknown
        when Prism::CallNode
          infer_call_type(node)
        when Prism::LambdaNode
          # Lambda type
          param_types = []
          if node.parameters
            params = node.parameters.parameters
            params.requireds.each { |p| param_types << TypeFactory.unknown }
          end
          return_type = node.body ? infer_type(node.body.body.last) : TypeFactory.unknown
          TypeFactory.proc([], return_type)
        when Prism::BlockNode
          if node.body
            infer_type(node.body.body.last)
          else
            TypeFactory.unknown
          end
        when Prism::IfNode
          # Union of both branches. Prism stores the then-branch in `statements`
          # (a StatementsNode) and the else/elsif branch in `subsequent`.
          then_type = branch_result_type(node.statements)
          else_type = branch_result_type(node.subsequent)
          if then_type == else_type
            then_type
          else
            TypeFactory.union(then_type, else_type)
          end
        when Prism::CaseNode
          # Union of all when branches. Prism names these `conditions`.
          branch_types = node.conditions.map { |condition| branch_result_type(condition.statements) }
          branch_types << branch_result_type(node.else_clause&.statements) if node.else_clause
          if branch_types.uniq.size == 1
            branch_types.first
          else
            TypeFactory.union(*branch_types.uniq)
          end
        else
          TypeFactory.unknown
        end
      end

      # Infer the result type of a branch body. Prism wraps branches in
      # StatementsNode; `subsequent` may be an ElseNode or a nested IfNode (elsif).
      def branch_result_type(node)
        return TypeFactory::NIL_CLASS unless node

        case node
        when Prism::StatementsNode
          node.body.empty? ? TypeFactory::NIL_CLASS : infer_type(node.body.last)
        when Prism::ElseNode
          branch_result_type(node.statements)
        when Prism::IfNode
          infer_type(node)
        else
          infer_type(node)
        end
      end

      def infer_call_type(node)
        receiver_type = node.receiver ? infer_type(node.receiver) : TypeFactory.unknown
        method_name = node.name
        args = node.arguments&.arguments || []
        arg_types = args.map { |arg| infer_type(arg) }

        # Look up method signature
        infer_call_result_type(receiver_type, method_name, arg_types)
      end

      def infer_call_result_type(receiver_type, method_name, arg_types)
        # Built-in method signatures
        case method_name
        when :to_s, :to_str
          TypeFactory::STRING
        when :to_i, :to_int
          TypeFactory::INTEGER
        when :to_f, :to_float
          TypeFactory::FLOAT
        when :to_a, :to_ary
          TypeFactory::ARRAY
        when :to_h, :to_hash
          TypeFactory::HASH
        when :to_sym, :intern
          TypeFactory::SYMBOL
        when :nil?
          TypeFactory::BOOLEAN
        when :empty?
          TypeFactory::BOOLEAN
        when :present?, :blank?
          TypeFactory::BOOLEAN
        when :length, :size
          TypeFactory::INTEGER
        when :[], :fetch
          # Hash/Array access - depends on receiver
          if receiver_type.primitive? && receiver_type.name == :Hash
          elsif receiver_type.primitive? && receiver_type.name == :Array
          end
          TypeFactory.unknown
        when :first, :last
          TypeFactory.unknown
        when :map, :collect, :each
          TypeFactory::ARRAY
        when :select, :filter, :reject
          TypeFactory::ARRAY
        when :where, :find_by, :find_by!, :all, :find
          if receiver_type.class_type?
            TypeFactory.class_type(receiver_type.name)
          else
            TypeFactory.unknown
          end
        when :create, :new, :build
          if receiver_type.class_type?
            TypeFactory.class_type(receiver_type.name)
          else
            TypeFactory.unknown
          end
        when :update, :save, :save!
          TypeFactory::BOOLEAN
        when :destroy, :delete
          TypeFactory::BOOLEAN
        else
          # Check if receiver has this method defined
          if receiver_type.class_type? && receiver_type.respond_to?(:methods)
            method_info = receiver_type.methods[method_name]
            if method_info
              return method_info[:return_type]
            end
          end
          TypeFactory.unknown
        end
      end

      def infer_return_type(body)
        return nil unless body

        # Last expression in the body is the return value. `infer_type` already
        # returns unknown for any node it does not recognize.
        node = body.is_a?(Prism::StatementsNode) ? body.body.last : body
        infer_type(node)
      end

      def infer_type_from_literal(node)
        case node
        when Prism::IntegerNode
          TypeFactory::INTEGER
        when Prism::FloatNode
          TypeFactory::FLOAT
        when Prism::StringNode
          TypeFactory::STRING
        when Prism::SymbolNode
          TypeFactory::SYMBOL
        when Prism::TrueNode
          TypeFactory::TRUE_CLASS
        when Prism::FalseNode
          TypeFactory::FALSE_CLASS
        when Prism::NilNode
          TypeFactory::NIL_CLASS
        when Prism::ArrayNode
          TypeFactory::ARRAY
        when Prism::HashNode
          TypeFactory::HASH
        when Prism::RangeNode
          TypeFactory::RANGE
        when Prism::RegularExpressionNode
          TypeFactory::REGEXP
        else
          TypeFactory.unknown
        end
      end
    end
  end
end
