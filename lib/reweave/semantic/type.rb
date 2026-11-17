# frozen_string_literal: true

module Reweave
  module Semantic
    # Base class for all types in the type system
    class Type
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def ==(other)
        other.is_a?(self.class) && other.name == name
      end
      alias_method :eql?, :==

      def hash
        [self.class, name].hash
      end

      def to_s
        name.to_s
      end
      alias_method :inspect, :to_s

      def primitive?
        false
      end

      def class_type?
        false
      end

      def union?
        false
      end

      def unknown?
        is_a?(UnknownType)
      end

      def nilable?
        false
      end
    end

    # Primitive types (Integer, String, Symbol, TrueClass, FalseClass, NilClass, Float, Array, Hash, etc.)
    class PrimitiveType < Type
      PRIMITIVES = %i[Integer String Symbol TrueClass FalseClass NilClass Float Array Hash Range Regexp Time Date DateTime].freeze

      def initialize(name)
        super
        @primitive = PRIMITIVES.include?(name)
      end

      def primitive?
        @primitive
      end

      def self.from_ruby_class(klass)
        new(klass.name.to_sym)
      end
    end

    # Class/module types (User, ActiveRecord::Base, etc.)
    class ClassType < Type
      attr_reader :namespace, :superclass, :includes, :constants, :defined_methods

      def initialize(name, namespace: nil, superclass: nil)
        super(name)
        @namespace = namespace
        @superclass = superclass
        @includes = []
        @constants = {}
        @defined_methods = {}
      end

      def class_type?
        true
      end

      def add_method(name, return_type, param_types = [])
        @defined_methods[name.to_sym] = {return_type: return_type, param_types: param_types}
      end

      def methods
        @defined_methods
      end

      def add_constant(name, type)
        @constants[name.to_sym] = type
      end

      def add_include(mod_name)
        @includes << mod_name.to_s
      end

      def ancestor_chain
        chain = [self]
        current = @superclass
        while current
          chain << current
          current = current.superclass
        end
        chain
      end
    end

    # Module types
    class ModuleType < ClassType
      def initialize(name, namespace: nil)
        super
      end
    end

    # Union types (A | B)
    class UnionType < Type
      attr_reader :types

      def initialize(types)
        super("Union")
        @types = types.uniq
      end

      def union?
        true
      end

      def primitive?
        types.all?(&:primitive?)
      end

      def class_type?
        types.all?(&:class_type?)
      end

      def add_type(type)
        @types << type unless @types.include?(type)
      end

      def to_s
        types.join(" | ")
      end
    end

    # Unknown type (when type cannot be inferred)
    class UnknownType < Type
      def initialize
        super("Unknown")
      end

      def unknown?
        true
      end
    end

    # Nilable type wrapper (T | nil)
    class NilableType < Type
      attr_reader :inner_type

      def initialize(inner_type)
        super("Nilable")
        @inner_type = inner_type
      end

      def nilable?
        true
      end

      def to_s
        "#{inner_type} | nil"
      end

      def inner_types
        [inner_type, PrimitiveType.new(:NilClass)]
      end
    end

    # Proc/lambda type with parameter and return types
    class ProcType < Type
      attr_reader :param_types, :return_type

      def initialize(param_types, return_type)
        super("Proc")
        @param_types = param_types
        @return_type = return_type
      end

      def to_s
        params = param_types.join(", ")
        "Proc(#{params}) -> #{return_type}"
      end
    end

    # Type builder factory
    class TypeFactory
      def self.primitive(name)
        PrimitiveType.new(name)
      end

      def self.class_type(name, namespace: nil, superclass: nil)
        ClassType.new(name, namespace: namespace, superclass: superclass)
      end

      def self.module_type(name, namespace: nil)
        ModuleType.new(name, namespace: namespace)
      end

      def self.union(*types)
        UnionType.new(types)
      end

      def self.nilable(inner_type)
        NilableType.new(inner_type)
      end

      def self.proc(param_types, return_type)
        ProcType.new(param_types, return_type)
      end

      def self.unknown
        UnknownType.new
      end

      def self.from_ruby_class(klass)
        case klass.name
        when "Integer", "String", "Symbol", "TrueClass", "FalseClass", "NilClass", "Float", "Array", "Hash", "Range", "Regexp", "Time", "Date", "DateTime"
          PrimitiveType.new(klass.name.to_sym)
        else
          ClassType.new(klass.name.to_sym)
        end
      end

      # Common type instances
      INTEGER = PrimitiveType.new(:Integer)
      STRING = PrimitiveType.new(:String)
      SYMBOL = PrimitiveType.new(:Symbol)
      TRUE_CLASS = PrimitiveType.new(:TrueClass)
      FALSE_CLASS = PrimitiveType.new(:FalseClass)
      NIL_CLASS = PrimitiveType.new(:NilClass)
      FLOAT = PrimitiveType.new(:Float)
      ARRAY = PrimitiveType.new(:Array)
      HASH = PrimitiveType.new(:Hash)
      RANGE = PrimitiveType.new(:Range)
      REGEXP = PrimitiveType.new(:Regexp)
      TRUE = PrimitiveType.new(:TrueClass)
      FALSE = PrimitiveType.new(:FalseClass)
      NIL = PrimitiveType.new(:NilClass)
      BOOLEAN = UnionType.new([TRUE_CLASS, FALSE_CLASS])
      STRING_OR_NIL = UnionType.new([STRING, NIL_CLASS])
      UNKNOWN = UnknownType.new
    end
  end
end
