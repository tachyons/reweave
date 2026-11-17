# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module Ruby
      # Declarative version of RenameMethod using the new DSL
      class DeclarativeRename < Reweave::Recipe::DeclarativeRecipe
        display_name "Declarative rename method"
        description "Renames a method call using the declarative DSL"

        option :old_name, type: String, required: true, description: "Old method name"
        option :new_name, type: String, required: true, description: "New method name"
        option :receiver, type: String, required: false, description: "Optional receiver to match"

        transform_call(
          method: ->(instance) { ->(name) { name.to_s == instance.config[:old_name] } },
          receiver: ->(instance) { instance.config[:receiver] },
          args: ->(instance) { ->(node) { true } }
        ) do |node, instance|
          node.replace_location(node.message_loc, instance.config[:new_name])
        end
      end
    end
  end
end
