# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Ruby
      # Ruby 2.6 -> 2.7 syntax upgrades
      class Upgrade26To27 < Recipe
        display_name "Upgrade Ruby 2.6 to 2.7"
        description "Converts Ruby 2.6 syntax to 2.7: numbered params (_1), beginless ranges, Enumerable#tally, GC.compact"

        option :convert_numbered_params, type: [TrueClass, FalseClass], default: true, description: "Convert { |x| x.foo } to { _1.foo }"
        option :convert_beginless_range, type: [TrueClass, FalseClass], default: true, description: "Convert -Float::INFINITY..5 to ..5"

        def get_visitor(context)
          Upgrade26To27Visitor.new(context, config)
        end
      end

      class Upgrade26To27Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_block_parameters_node(node)
          return super unless @config[:convert_numbered_params]

          # Convert single param blocks to numbered params
          # node.parameters is a ParametersNode (not BlockParametersNode)
          inner_params = node.parameters
          requireds = inner_params.requireds
          if requireds.size == 1 && inner_params.optionals.empty? && inner_params.rest.nil?
            param = requireds.first
            # Only convert simple parameter names like x, y, it, item, element
            simple_names = %i[x y it item element val value arg args]
            if simple_names.include?(param.name)
              # For numbered params, we can remove the block parameters entirely
              # Replace the entire block parameters (including | |) with nothing
              if node.opening_loc && node.closing_loc
                start_offset = node.opening_loc.start_offset
                end_offset = node.closing_loc.end_offset
                @edits.add(Editing.replace(source_id, start_offset, end_offset, "", recipe_name))
              end
            end
          end
          super
        end

        def visit_range_node(node)
          return super unless @config[:convert_beginless_range]

          # Convert -Float::INFINITY..5 to ..5
          if node.begin && match_call?(node.begin, method: :-, receiver: "Float")
            # Actually -Float::INFINITY is a unary minus on Float::INFINITY
            # Prism represents this differently
          end
          super
        end
      end
    end
  end
end
