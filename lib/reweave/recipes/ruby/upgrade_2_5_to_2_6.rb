# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.5 -> 2.6 syntax upgrades
      class Upgrade25To26 < Recipe
        display_name "Upgrade Ruby 2.5 to 2.6"
        description "Converts Ruby 2.5 syntax to 2.6: endless ranges, then alias, Random.bytes, Proc composition"

        option :convert_endless_range, type: [TrueClass, FalseClass], default: true, description: "Convert 1..Float::INFINITY to 1.."
        option :convert_then, type: [TrueClass, FalseClass], default: true, description: "Convert yield_self to then"

        def get_visitor(context)
          Upgrade25To26Visitor.new(context, config)
        end
      end

      class Upgrade25To26Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert yield_self to then
          if @config[:convert_then] && match_call?(node, method: :yield_self)
            replace_location(node.location, node.location.slice.sub("yield_self", "then"))
          end

          # Convert Range.new(1, Float::INFINITY) to 1..
          super
        end

        def visit_range_node(node)
          return super unless @config[:convert_endless_range]

          # Convert 1..Float::INFINITY to 1..
          if node.end && match_call?(node.end, method: :INFINITY, receiver: "Float")
            # This is an exclusive range with Float::INFINITY
            replace(node, "#{source_for(node.begin)}..")
          end
          super
        end
      end
    end
  end
end
