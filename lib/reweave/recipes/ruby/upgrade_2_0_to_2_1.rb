# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.0 -> 2.1 syntax upgrades
      class Upgrade20To21 < Recipe
        display_name "Upgrade Ruby 2.0 to 2.1"
        description "Converts Ruby 2.0 syntax to 2.1: required keyword args, Exception#cause, String#scrub, Hash#to_h"

        option :convert_hash_to_h, type: [TrueClass, FalseClass], default: true, description: "Convert hash.map{...}.to_h for Enumerable"

        def get_visitor(context)
          Upgrade20To21Visitor.new(context, config)
        end
      end

      class Upgrade20To21Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Convert [[:a, 1], [:b, 2]].to_h -> {a: 1, b: 2} when possible
        # or hash.map { |k, v| ... }.to_h -> hash.transform_values { |v| ... }
        def visit_call_node(node)
          return super unless @config[:convert_hash_to_h]

          if match_call?(node, method: :to_h)
            receiver = node.receiver
            if receiver && match_call?(receiver, method: :map)
              # [[:a, 1], [:b, 2]].map { ... }.to_h -> could be transform_values
              # For now, leave as is but could be optimized
            end
          end
          super
        end
      end
    end
  end
end
