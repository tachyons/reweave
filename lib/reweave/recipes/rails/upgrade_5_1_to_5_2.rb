# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 5.1 -> 5.2 syntax upgrades
      class Upgrade51To52 < Recipe
        display_name "Upgrade Rails 5.1 to 5.2"
        description "Converts Rails 5.1 syntax to 5.2: ActiveStorage, Redis cache store, etc."

        option :convert_active_storage, type: [TrueClass, FalseClass], default: true, description: "Convert paperclip/carrierwave to ActiveStorage"
        option :convert_redis_cache, type: [TrueClass, FalseClass], default: true, description: "Convert cache store to Redis"

        def get_visitor(context)
          Upgrade51To52Visitor.new(context, config)
        end
      end

      class Upgrade51To52Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert Redis cache store
          if @config[:convert_redis_cache] && match_call?(node, method: :cache_store)
            args = extract_arguments(node)
            if args.size >= 1
              first = args[0]
              if first.is_a?(Prism::SymbolNode) && first.value == "redis_store"
                # Already redis
              elsif first.is_a?(Prism::SymbolNode) && first.value == "mem_cache_store"
                # Convert to redis
                replace(node, "config.cache_store = :redis_cache_store")
              end
            end
          end

          super
        end
      end
    end
  end
end
