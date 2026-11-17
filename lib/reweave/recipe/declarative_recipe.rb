# frozen_string_literal: true

require_relative "recipe"
require_relative "dsl"
require_relative "../visitor/ruby_visitor"
require_relative "../ast/node"

# Define DeclarativeRecipe as a nested class of Reweave::Recipe
class Reweave::Recipe::DeclarativeRecipe < Reweave::Recipe
  include Reweave::DSL

  def get_visitor(context)
    DeclarativeVisitor.new(context, self)
  end
end

class Reweave::Recipe::DeclarativeVisitor < Reweave::Visitor::RubyVisitor
  include Reweave::AST

  def initialize(context, recipe_class)
    super(context, nil)
    @recipe_class = recipe_class
  end

  def run(source_file)
    @source_file = source_file
    traverse(source_file.root)
    edits
  end

  def visit_call_node(node)
    apply_transforms(node, @source_file)
    super
  end

  def visit_def_node(node)
    apply_transforms(node, @source_file)
    super
  end

  def visit_class_node(node)
    apply_transforms(node, @source_file)
    super
  end

  def visit_module_node(node)
    apply_transforms(node, @source_file)
    super
  end

  def visit_constant_read_node(node)
    apply_transforms(node, @source_file)
    super
  end

  private

  def apply_transforms(node, source_file)
    ast_node = Node.new(node, source: source_file.source, source_file: source_file)

    # Apply call transforms
    @recipe_class.class.call_transforms.each do |transform|
      next unless ast_node.call?
      next unless match_method?(ast_node, transform[:method])
      next unless match_receiver?(ast_node, transform[:receiver])
      next unless match_args?(ast_node, transform[:args])
      transform[:block].call(ast_node, @recipe_class)
    end

    # Apply def transforms
    if ast_node.def?
      @recipe_class.class.def_transforms.each do |transform|
        next unless match_method?(ast_node, transform[:name])
        transform[:block].call(ast_node, @recipe_class)
      end
    end

    # Apply class transforms
    if ast_node.class?
      @recipe_class.class.class_transforms.each do |transform|
        next unless match_method?(ast_node, transform[:name])
        transform[:block].call(ast_node, @recipe_class)
      end
    end

    # Apply constant transforms
    if ast_node.constant?
      @recipe_class.class.constant_transforms.each do |transform|
        next unless match_method?(ast_node, transform[:name])
        transform[:block].call(ast_node, @recipe_class)
      end
    end
  end

  def match_method?(node, pattern)
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
          match_method?(node, resolved)
        end
      else
        pattern.call(node.method_name)
      end
    else
      false
    end
  end

  def match_receiver?(node, pattern)
    return true unless pattern
    recv = node.receiver
    return false unless recv
    case pattern
    when String
      recv.receiver_name == pattern || recv.constant_name == pattern
    when Regexp
      (recv.receiver_name || recv.constant_name || "").match?(pattern)
    when Proc
      if pattern.arity == 1
        resolved = pattern.call(@recipe_class)
        if resolved.is_a?(Proc)
          resolved.call(recv)
        else
          match_receiver?(node, resolved)
        end
      else
        pattern.call(recv)
      end
    else
      false
    end
  end

  def match_args?(node, pattern)
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
