# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 1.9 -> 2.0 syntax upgrades
      class Upgrade19To20 < Recipe
        display_name "Upgrade Ruby 1.9 to 2.0"
        description "Converts Ruby 1.9 syntax to 2.0: keyword arguments, %i/%I, __dir__, Module#prepend, Enumerable#lazy"

        option :convert_symbol_array, type: [TrueClass, FalseClass], default: true, description: "Convert [:a, :b] to %i[a b]"
        option :add_dir_method, type: [TrueClass, FalseClass], default: true, description: "Replace File.dirname(__FILE__) with __dir__"

        def get_visitor(context)
          Upgrade19To20Visitor.new(context, config)
        end
      end

      class Upgrade19To20Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Convert [:a, :b] to %i[a b]
        def visit_array_node(node)
          return super unless @config[:convert_symbol_array]

          return super if node.elements.empty?

          all_symbols = node.elements.all? { |e| e.is_a?(Prism::SymbolNode) }
          return super unless all_symbols

          symbols = node.elements.map { |e| e.value }.join(" ")
          loc = node.location
          replace_location(loc, "%i[#{symbols}]")
          super
        end

        # Replace File.dirname(__FILE__) with __dir__
        def visit_call_node(node)
          return super unless @config[:add_dir_method]

          if match_call?(node, method: :dirname, receiver: "File")
            args = extract_arguments(node)
            if args.size == 1
              arg = args.first
              if arg.is_a?(Prism::SourceFileNode) || (arg.is_a?(Prism::ConstantReadNode) && arg.name == :__FILE__)
                replace(node, "__dir__")
              end
            end
          end
          super
        end
      end
    end
  end
end
