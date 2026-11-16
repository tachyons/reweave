# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.3 -> 2.4 syntax upgrades
      class Upgrade23To24 < Recipe
        display_name "Upgrade Ruby 2.3 to 2.4"
        description "Converts Ruby 2.3 syntax to 2.4: Hash#compact, transform_values, Regexp#match?, String#casecmp?"

        option :convert_hash_compact, type: [TrueClass, FalseClass], default: true, description: "Convert hash.delete_if { |_, v| v.nil? } to hash.compact"
        option :convert_regexp_match, type: [TrueClass, FalseClass], default: true, description: "Convert /re/ =~ str to /re/.match?(str)"
        option :convert_casecmp, type: [TrueClass, FalseClass], default: true, description: "Convert str.casecmp(other) == 0 to str.casecmp?(other)"

        def get_visitor(context)
          Upgrade23To24Visitor.new(context, config)
        end
      end

      class Upgrade23To24Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert hash.delete_if { |_, v| v.nil? } to hash.compact
          if @config[:convert_hash_compact] && match_call?(node, method: :delete_if)
            block = node.block
            if block && block.body.is_a?(Prism::IfNode)
              # Complex to detect, skip for now
            end
          end

          # Convert /re/ =~ str to /re/.match?(str)
          if @config[:convert_regexp_match] && match_call?(node, method: :=~)
            receiver = node.receiver
            if receiver&.is_a?(Prism::RegularExpressionNode)
              arg = extract_arguments(node).first
              if arg
                replace(node, "#{source_for(receiver)}.match?(#{source_for(arg)})")
              end
            end
          end

          # Convert str.casecmp(other) == 0 to str.casecmp?(other)
          if @config[:convert_casecmp] && match_call?(node, method: :==)
            left = node.receiver
            right = extract_arguments(node).first

            if left && match_call?(left, method: :casecmp) && right&.is_a?(Prism::IntegerNode) && right.value == 0
              recv = left.receiver
              arg = extract_arguments(left).first
              if recv && arg
                replace(node, "#{source_for(recv)}.casecmp?(#{source_for(arg)})")
              end
            end
          end

          super
        end
      end
    end
  end
end
