# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Migrate cache store to SolidCache
      class SolidCacheMigration < Recipe
        display_name "SolidCache migration"
        description "Migrates cache store configuration to SolidCache"

        def get_visitor(context)
          SolidCacheMigrationVisitor.new(context)
        end
      end

      class SolidCacheMigrationVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # config.cache_store = :redis_cache_store -> :solid_cache_store
          # config.cache_store = :mem_cache_store -> :solid_cache_store
          # config.cache_store = :memory_store -> :solid_cache_store
          replace_config_value(node, %w[config], %w[redis_cache_store mem_cache_store memory_store], "solid_cache_store", method: :cache_store=)

          super
        end
      end
    end
  end
end
