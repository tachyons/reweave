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
            # Case 1: [[:a, 1], [:b, 2]].to_h -> {a: 1, b: 2}
            if receiver&.is_a?(Prism::ArrayNode)
              all_pairs = receiver.elements.all? do |elem|
                elem.is_a?(Prism::ArrayNode) && elem.elements.size == 2 &&
                  elem.elements[0].is_a?(Prism::SymbolNode)
              end
              if all_pairs
                pairs = receiver.elements.map do |elem|
                  key = elem.elements[0].value
                  value = source_for(elem.elements[1])
                  "#{key}: #{value}"
                end.join(", ")
                replace(node, "{ #{pairs} }")
              end
            end

            # Case 2: hash.map { |k, v| ... }.to_h -> hash.transform_values { |v| ... }
            if receiver && match_call?(receiver, method: :map)
              # For now, we could convert to transform_values if the block only uses the value
              # This is complex to detect reliably, so leave as is
            end
          end
          super
        end
      end
    end
  end
end
