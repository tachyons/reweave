# frozen_string_literal: true

require_relative "type"

module Reweave
  module Semantic
    # Table storing all inferred type information
    class TypeTable
      attr_reader :calls, :node_types

      def initialize
        @classes = {}           # class_name => ClassType
        @modules = {}           # module_name => ModuleType
        @constants = {}         # constant_name => Type
        @methods = {}           # method_name => { param_types: [], return_type: Type }
        @variables = {}         # var_name => Type
        @ivars = {}             # ivar_name => Type
        @calls = []             # call nodes with type info
        @node_types = {}        # node_id => Type
        @variable_types = {}    # var_name => Type
      end

      # Class/module registration
      def add_class(name, class_type)
        @classes[name.to_s] = class_type
      end

      def add_module(name, module_type)
        @modules[name.to_s] = module_type
      end

      def class_type(name)
        @classes[name.to_s]
      end

      def module_type(name)
        @modules[name.to_s]
      end

      # Constant types
      def add_constant(name, type)
        @constants[name.to_s] = type
      end

      def constant_type(name)
        @constants[name.to_s]
      end

      # Method signatures
      def add_method(name, param_types, return_type)
        @methods[name.to_sym] = {param_types: param_types, return_type: return_type}
      end

      def method_signature(name)
        @methods[name.to_sym]
      end

      # Variable types
      def set_variable_type(name, type)
        @variables[name.to_sym] = type
        @variable_types[name.to_sym] = type
      end

      def variable_type(name)
        @variables[name.to_sym] || @variable_types[name.to_sym]
      end

      # Instance variable types
      def set_ivar_type(name, type)
        @ivars[name.to_sym] = type
      end

      def ivar_type(name)
        @ivars[name.to_sym]
      end

      # Call tracking
      def add_call(node, receiver_type, method_name, arg_types)
        @calls << {node: node, receiver_type: receiver_type, method_name: method_name, arg_types: arg_types}
      end

      # Node type mapping
      def set_node_type(node, type)
        @node_types[node.object_id] = type
      end

      def node_type(node)
        @node_types[node.object_id]
      end

      def all_classes
        @classes
      end

      def all_modules
        @modules
      end

      def all_constants
        @constants
      end

      def all_methods
        @methods
      end

      def all_variables
        @variables
      end

      def all_ivars
        @ivars
      end

      def stats
        {
          classes: @classes.size,
          modules: @modules.size,
          constants: @constants.size,
          methods: @methods.size,
          variables: @variables.size,
          ivars: @ivars.size,
          calls: @calls.size,
          node_types: @node_types.size
        }
      end

      # Merge another type table into this one
      def merge!(other)
        @classes.merge!(other.all_classes) { |_key, v1, v2| merge_types(v1, v2) }
        @modules.merge!(other.all_modules) { |_key, v1, v2| merge_types(v1, v2) }
        @constants.merge!(other.all_constants)
        @methods.merge!(other.all_methods)
        @variables.merge!(other.all_variables)
        @ivars.merge!(other.all_ivars)
        @calls.concat(other.calls)
        @node_types.merge!(other.node_types)
      end

      private

      def merge_types(t1, t2)
        return t1 if t1 == t2
        # For now, prefer t1; could be enhanced with type union
        t1
      end
    end
  end
end
