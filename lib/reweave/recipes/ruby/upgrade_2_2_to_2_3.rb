# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.2 -> 2.3 syntax upgrades
      class Upgrade22To23 < Recipe
        display_name "Upgrade Ruby 2.2 to 2.3"
        description "Converts Ruby 2.2 syntax to 2.3: safe navigation (&.), Hash#dig, frozen string literal, Hash#to_proc"

        option :convert_safe_navigation, type: [TrueClass, FalseClass], default: true, description: "Convert obj && obj.method to obj&.method"
        option :convert_hash_dig, type: [TrueClass, FalseClass], default: true, description: "Convert hash[:a][:b] to hash.dig(:a, :b)"
        option :add_frozen_string_literal, type: [TrueClass, FalseClass], default: false, description: "Add # frozen_string_literal: true comment"

        def get_visitor(context)
          Upgrade22To23Visitor.new(context, config)
        end
      end

      class Upgrade22To23Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        # Visit AndNode for safe navigation conversion: obj && obj.method -> obj&.method
        def visit_and_node(node)
          return super unless @config[:convert_safe_navigation]

          left = node.left
          right = node.right

          if left.is_a?(Prism::CallNode) && right.is_a?(Prism::CallNode)
            # Left is the receiver (e.g., `user`), right is the call (e.g., `user.name`)
            # Check if right's receiver has the same name as left
            right_recv = right.receiver
            if right_recv.is_a?(Prism::CallNode) && right_recv.name == left.name
              method_name = right.name
              left_name = left.name.to_s
              replace(node, "#{left_name}&.#{method_name}")
            end
          end
          super
        end

        def visit_call_node(node)
          # Convert hash[:a][:b] to hash.dig(:a, :b)
          if @config[:convert_hash_dig] && match_call?(node, method: :[])
            # Nested hash access like hash[:a][:b] would be a CallNode on a CallNode
            receiver = node.receiver
            if receiver && match_call?(receiver, method: :[])
              # This is hash[:a][:b] pattern
              outer_key = extract_arguments(node).first
              inner_key = extract_arguments(receiver).first
              recv = receiver.receiver
              if recv && outer_key && inner_key
                replace(node, "#{source_for(recv)}.dig(#{source_for(inner_key)}, #{source_for(outer_key)})")
              end
            end
          end
          super
        end
      end
    end
  end
end
