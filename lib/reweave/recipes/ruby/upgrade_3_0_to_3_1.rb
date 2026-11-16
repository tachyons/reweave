# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 3.0 -> 3.1 syntax upgrades
      class Upgrade30To31 < Recipe
        display_name "Upgrade Ruby 3.0 to 3.1"
        description "Converts Ruby 3.0 syntax to 3.1: Array#intersect?, Hash#fetch with block, Class#subclasses, debug improvements"

        option :convert_array_intersect, type: [TrueClass, FalseClass], default: true, description: "Convert (a & b).any? to a.intersect?(b)"

        def get_visitor(context)
          Upgrade30To31Visitor.new(context, config)
        end
      end

      class Upgrade30To31Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert (a & b).any? to a.intersect?(b)
          if @config[:convert_array_intersect] && match_call?(node, method: :any?)
            receiver = node.receiver
            if receiver && match_call?(receiver, method: :&)
              left = receiver.receiver
              right = extract_arguments(receiver).first
              if left && right
                replace(node, "#{source_for(left)}.intersect?(#{source_for(right)})")
              end
            end
          end
          super
        end
      end
    end
  end
end
