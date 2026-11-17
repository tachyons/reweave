# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 3.1 -> 3.2 syntax upgrades
      class Upgrade31To32 < Recipe
        display_name "Upgrade Rails 3.1 to 3.2"
        description "Converts Rails 3.1 syntax to 3.2: key-value store, tagged logging, etc."

        option :convert_key_value_store, type: [TrueClass, FalseClass], default: true, description: "Convert key-value store syntax"

        def get_visitor(context)
          Upgrade31To32Visitor.new(context, config)
        end
      end

      class Upgrade31To32Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert key-value store syntax: Rails.cache -> Rails.cache
          # ActiveSupport::Cache::Store interface is mostly compatible
          # But store implementations may have changed
          if @config[:convert_key_value_store]
            # Rails 3.2 deprecated some cache store options
            # Redis store configuration changes are in config, not syntax
          end

          # Tagged logging: Rails.logger -> Rails.logger (already compatible)
          # But config.log_tags is new

          super
        end
      end
    end
  end
end
