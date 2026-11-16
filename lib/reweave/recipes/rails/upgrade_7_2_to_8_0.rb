# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 7.2 -> 8.0 syntax upgrades
      class Upgrade72To80 < Recipe
        display_name "Upgrade Rails 7.2 to 8.0"
        description "Converts Rails 7.2 syntax to 8.0: Solid Queue, Solid Cache, Solid Cable, etc."

        option :convert_solid_queue, type: [TrueClass, FalseClass], default: true, description: "Convert ActiveJob to SolidQueue"
        option :convert_solid_cache, type: [TrueClass, FalseClass], default: true, description: "Convert cache store to SolidCache"
        option :convert_solid_cable, type: [TrueClass, FalseClass], default: true, description: "Convert ActionCable to SolidCable"
        option :convert_propshaft, type: [TrueClass, FalseClass], default: true, description: "Convert Sprockets to Propshaft"
        option :convert_ruby_version, type: [TrueClass, FalseClass], default: true, description: "Update Ruby version requirement"

        def get_visitor(context)
          Upgrade72To80Visitor.new(context, config)
        end
      end

      class Upgrade72To80Visitor < Reweave::Visitor::RubyVisitor
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
          # Convert queue_adapter to SolidQueue
          if @config[:convert_solid_queue] && match_call?(node, method: :queue_adapter)
            args = extract_arguments(node)
            if args.size == 1
              first = args[0]
              if first.is_a?(Prism::SymbolNode)
                replace(node, "config.active_job.queue_adapter = :solid_queue")
              end
            end
          end

          # Convert cache_store to SolidCache
          if @config[:convert_solid_cache] && match_call?(node, method: :cache_store)
            args = extract_arguments(node)
            if args.size == 1
              first = args[0]
              if first.is_a?(Prism::SymbolNode) && %w[redis_store mem_cache_store].include?(first.value)
                replace(node, "config.cache_store = :solid_cache_store")
              end
            end
          end

          # Convert cable adapter
          if @config[:convert_solid_cable] && match_call?(node, method: :cable)
            # config.cable.url = "redis://..."
            # Convert to solid_cable
          end

          # Update Ruby version in Gemfile
          if @config[:convert_ruby_version] && match_call?(node, method: :ruby)
            args = extract_arguments(node)
            if args.size == 1 && args.first.is_a?(Prism::StringNode)
              version = args.first.unescaped
              if Gem::Version.new(version) < Gem::Version.new("3.2")
                replace(node, "ruby \"3.2\"")
              end
            end
          end

          super
        end
      end
    end
  end
end
