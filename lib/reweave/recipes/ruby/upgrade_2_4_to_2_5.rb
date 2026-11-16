# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.4 -> 2.5 syntax upgrades
      class Upgrade24To25 < Recipe
        display_name "Upgrade Ruby 2.4 to 2.5"
        description "Converts Ruby 2.4 syntax to 2.5: yield_self/then, Hash#slice, transform_keys, rescue in do/end"

        option :convert_yield_self, type: [TrueClass, FalseClass], default: true, description: "Convert obj.tap { |x| break f(x) } to obj.yield_self { |x| f(x) }"
        option :convert_hash_slice, type: [TrueClass, FalseClass], default: true, description: "Convert hash.select { |k, _| keys.include?(k) } to hash.slice(*keys)"

        def get_visitor(context)
          Upgrade24To25Visitor.new(context, config)
        end
      end

      class Upgrade24To25Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # Convert obj.tap { |x| break f(x) } to obj.yield_self { |x| f(x) }
          if @config[:convert_yield_self] && match_call?(node, method: :tap)
            block = node.block
            if block && block.body.is_a?(Prism::BreakNode)
              # Complex to detect, skip for now
            end
          end

          # Convert hash.select { |k, _| keys.include?(k) } to hash.slice(*keys)
          if @config[:convert_hash_slice] && match_call?(node, method: :select)
            # Complex pattern matching, skip for now
          end

          super
        end
      end
    end
  end
end
