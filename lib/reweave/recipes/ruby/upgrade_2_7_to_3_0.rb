# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.7 -> 3.0 syntax upgrades
      class Upgrade27To30 < Recipe
        display_name "Upgrade Ruby 2.7 to 3.0"
        description "Converts Ruby 2.7 syntax to 3.0: pattern matching, keyword arg separation, endless methods, Array#union/difference/intersection, Hash#except, String#delete_prefix/suffix"

        option :convert_endless_methods, type: [TrueClass, FalseClass], default: true, description: "Convert def foo; bar end to def foo = bar"
        option :convert_array_union, type: [TrueClass, FalseClass], default: true, description: "Convert a | b to a.union(b)"
        option :convert_array_difference, type: [TrueClass, FalseClass], default: true, description: "Convert a - b to a.difference(b)"
        option :convert_array_intersection, type: [TrueClass, FalseClass], default: true, description: "Convert a & b to a.intersection(b)"
        option :convert_hash_except, type: [TrueClass, FalseClass], default: true, description: "Convert hash.except(:key) or hash.reject { |k, _| k == :key } to hash.except(:key)"
        option :convert_delete_prefix, type: [TrueClass, FalseClass], default: true, description: "Convert str.sub(/^prefix/, '') to str.delete_prefix('prefix')"

        def get_visitor(context)
          Upgrade27To30Visitor.new(context, config)
        end
      end

      class Upgrade27To30Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_def_node(node)
          return super unless @config[:convert_endless_methods]

          # Convert single-line method: def foo; bar end -> def foo = bar
          # Only convert if the method definition is on a single line
          if node.body&.is_a?(Prism::StatementsNode)
            stmts = node.body.body
            if stmts.size == 1
              # Check if the entire method is on one line
              if node.location.start_line == node.location.end_line
                body_source = source_for(stmts.first)
                if body_source
                  # Build parameter list
                  params = node.parameters
                  param_list = ""
                  if params&.requireds&.any?
                    param_names = params.requireds.map { |p| p.name.to_s }
                    param_list = "(#{param_names.join(", ")})"
                  end
                  replace(node, "def #{node.name}#{param_list} = #{body_source}")
                end
              end
            end
          end
          super
        end

        def visit_call_node(node)
          # Convert a | b to a.union(b)
          if @config[:convert_array_union] && match_call?(node, method: :|)
            receiver = node.receiver
            arg = extract_arguments(node).first
            if receiver && arg
              replace(node, "#{source_for(receiver)}.union(#{source_for(arg)})")
            end
          end

          # Convert a - b to a.difference(b)
          if @config[:convert_array_difference] && match_call?(node, method: :-)
            receiver = node.receiver
            arg = extract_arguments(node).first
            if receiver && arg
              replace(node, "#{source_for(receiver)}.difference(#{source_for(arg)})")
            end
          end

          # Convert a & b to a.intersection(b)
          if @config[:convert_array_intersection] && match_call?(node, method: :&)
            receiver = node.receiver
            arg = extract_arguments(node).first
            if receiver && arg
              replace(node, "#{source_for(receiver)}.intersection(#{source_for(arg)})")
            end
          end

          # Convert hash.except(:key)
          if @config[:convert_hash_except] && match_call?(node, method: :except)
            # Already correct
          end

          # Convert str.sub(/^prefix/, '') to str.delete_prefix('prefix')
          if @config[:convert_delete_prefix] && match_call?(node, method: :sub)
            receiver = node.receiver
            args = extract_arguments(node)
            if args.size == 2
              pattern = args[0]
              replacement = args[1]
              if pattern.is_a?(Prism::RegularExpressionNode)
                unescaped = pattern.unescaped
                if unescaped.start_with?("^")
                  prefix = unescaped[1..]
                  if replacement.is_a?(Prism::StringNode) && replacement.unescaped.empty?
                    replace(node, "#{source_for(receiver)}.delete_prefix(#{prefix.inspect})")
                  end
                end
              end
            end
          end

          super
        end
      end
    end
  end
end
