# frozen_string_literal: true

require_relative "../../../reweave/recipe"

module Reweave
  module Recipes
    module Ruby
      class RenameMethod < Recipe
        display_name "Rename method"

        description "Renames a method call across the codebase."

        option :old_name, type: String, required: true, description: "Old method name"
        option :new_name, type: String, required: true, description: "New method name"
        option :receiver, type: String, required: false, description: "Optional receiver to match (e.g., 'User')"

        def get_visitor(context)
          RenameMethodVisitor.new(context, old_name: config[:old_name], new_name: config[:new_name], receiver: config[:receiver])
        end
      end

      class RenameMethodVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, old_name:, new_name:, receiver: nil)
          super(context, nil)
          @old_name = old_name.to_sym
          @new_name = new_name
          @receiver = receiver
        end

        def run(source_file)
          @source_file = source_file
          visit(source_file.root)
          edits
        end

        def visit_call_node(node)
          return super unless node.name == @old_name

          if @receiver
            receiver_name = extract_receiver_name(node)
            return super unless receiver_name == @receiver
          end

          # Replace just the method name
          loc = node.message_loc
          if loc
            replace_location(loc, @new_name)
          end

          super
        end
      end
    end
  end
end
