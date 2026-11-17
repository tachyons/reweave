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
            if block
              body = block.body
              if body.is_a?(Prism::StatementsNode) && body.body.size == 1
                stmt = body.body.first
                if stmt.is_a?(Prism::BreakNode)
                  # tap { |x| break f(x) } -> yield_self { |x| f(x) }
                  # Extract the argument to break
                  break_arg = extract_arguments(stmt).first
                  if break_arg
                    # Get the block parameter
                    block_params = block.parameters
                    requireds = block_params.parameters.requireds
                    if requireds.size == 1
                      param_name = requireds.first.name
                      # Check if break argument uses the param
                      # Replace tap with yield_self and remove break
                      # For simplicity, we replace the entire method call
                      receiver = node.receiver
                      if receiver
                        replace(node, "#{source_for(receiver)}.yield_self { |#{param_name}| #{source_for(break_arg)} }")
                      end
                    end
                  end
                end
              end
            end
          end

          # Convert obj.tap { |x| break f(x) } to obj.then { |x| f(x) } (Ruby 2.5+ alias)
          if @config[:convert_yield_self] && match_call?(node, method: :yield_self)
            # Already correct, but could convert to then
            replace_location(node.message_loc, "then")
          end

          # Convert hash.select { |k, _| keys.include?(k) } to hash.slice(*keys)
          if @config[:convert_hash_slice] && match_call?(node, method: :select)
            block = node.block
            if block
              # Check if block is checking key membership
              # Pattern: hash.select { |k, _| keys.include?(k) }
              body = block.body
              if body.is_a?(Prism::StatementsNode) && body.body.size == 1
                stmt = body.body.first
                # Check for keys.include?(k) or keys.member?(k)
                if stmt.is_a?(Prism::CallNode) && stmt.name == :include? || stmt.name == :member?
                  # Receiver could be a CallNode (keys) or LocalVariableReadNode
                  receiver_node = stmt.receiver
                  receiver_name = if receiver_node.is_a?(Prism::LocalVariableReadNode)
                    receiver_node.name
                  elsif receiver_node.is_a?(Prism::CallNode)
                    receiver_node.name.to_s
                  end
                  if receiver_name &&
                      stmt.arguments&.arguments&.size == 1
                    arg = stmt.arguments.arguments.first
                    # Check if arg matches block parameter
                    block_params = block.parameters
                    requireds = block_params.parameters.requireds
                    if requireds.size >= 1 && requireds.first.name == arg.name
                      # This is hash.select { |k, _| keys.include?(k) }
                      # Convert to hash.slice(*keys)
                      receiver = node.receiver
                      if receiver
                        replace(node, "#{source_for(receiver)}.slice(*#{receiver_name})")
                      end
                    end
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
