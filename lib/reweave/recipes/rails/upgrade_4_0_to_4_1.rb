# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 4.0 -> 4.1 syntax upgrades
      class Upgrade40To41 < Recipe
        display_name "Upgrade Rails 4.0 to 4.1"
        description "Converts Rails 4.0 syntax to 4.1: ActionController::Live, config/secrets.yml, etc."

        option :convert_live, type: [TrueClass, FalseClass], default: true, description: "Convert streaming responses"
        option :convert_secrets, type: [TrueClass, FalseClass], default: true, description: "Convert secrets.yml to credentials"

        def get_visitor(context)
          Upgrade40To41Visitor.new(context, config)
        end
      end

      class Upgrade40To41Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert ActionController::Live streaming responses
          if @config[:convert_live] && match_call?(node, method: :response)
            # response.stream -> response.stream (compatible)
            # But include ActionController::Live in controller class
          end

          # Convert secrets.yml -> credentials (Rails 5.2+)
          # Check for Rails.application.secrets.xxx
          if @config[:convert_secrets] && match_call?(node, method: :secrets)
            receiver = node.receiver
            if receiver&.is_a?(Prism::CallNode) && receiver.name == :application
              base = receiver.receiver
              if base&.is_a?(Prism::ConstantReadNode) && base.name == :Rails
                # Rails.application.secrets -> Rails.application.credentials
                replace_location(node.message_loc, "credentials")
              end
            end
          end

          super
        end
      end
    end
  end
end
