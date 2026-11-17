# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Replace deprecated Model.find(:all), Model.find(:first), Model.find(:last)
      class ReplaceDeprecatedFind < Recipe
        display_name "Replace deprecated find"
        description "Replaces deprecated ActiveRecord find(:all), find(:first), find(:last) with all, first, last"

        option :include_find_by, type: [TrueClass, FalseClass], default: true, description: "Also replace find_by_* dynamic finders"

        def get_visitor(context)
          ReplaceDeprecatedFindVisitor.new(context, include_find_by: config[:include_find_by])
        end
      end

      class ReplaceDeprecatedFindVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, include_find_by: true)
          super(context, nil)
          @include_find_by = include_find_by
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          return super unless node.receiver

          # Match Model.find(:all) -> Model.all
          if match_call?(node, method: :find)
            args = extract_arguments(node)
            if args.size == 1 && args.first.is_a?(Prism::SymbolNode)
              receiver = extract_receiver_name(node)
              case args.first.value
              when "all"
                replace(node, receiver + ".all")
              when "first"
                replace(node, receiver + ".first")
              when "last"
                replace(node, receiver + ".last")
              end
            end
          end

          # Match dynamic finders like find_by_name_and_email -> where(name: ..., email: ...).first
          if @include_find_by && node.name.to_s.start_with?("find_by_")
            method_name = node.name.to_s
            # Extract field names from find_by_name_and_email
            fields_str = method_name.delete_prefix("find_by_")
            fields = fields_str.split("_and_")

            # Build where clause
            fields.map do |field|
              arg = first_arg(node, Prism::SymbolNode, Prism::StringNode)
              if arg
                source_for(arg)
                # For dynamic finders, the argument is typically passed directly
                # But we need to extract all arguments
              end
            end

            args = extract_arguments(node)
            if args.size == fields.size
              where_clauses = fields.zip(args).map do |field, value|
                "#{field}: #{source_for(value)}"
              end.join(", ")
              receiver = extract_receiver_name(node)
              replace(node, "#{receiver}.where(#{where_clauses}).first")
            end
          end

          super
        end
      end
    end
  end
end
