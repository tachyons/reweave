# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Migrate ActiveJob queue adapter to SolidQueue
      class SolidQueueMigration < Recipe
        display_name "SolidQueue migration"
        description "Migrates ActiveJob queue adapter configuration to SolidQueue"

        def get_visitor(context)
          SolidQueueMigrationVisitor.new(context)
        end
      end

      class SolidQueueMigrationVisitor < Reweave::Visitor::RubyVisitor
        def initialize(context, **)
          super(context, nil)
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # config.active_job.queue_adapter = :sidekiq -> :solid_queue
          if match_call?(node, receiver: "config.active_job", method: :queue_adapter=)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::SymbolNode) && args.first.value == :sidekiq
              replace(args.first, ":solid_queue")
            end
          end

          # config.active_job.queue_adapter = "sidekiq" -> "solid_queue"
          if match_call?(node, receiver: "config.active_job", method: :queue_adapter=)
            args = extract_arguments(node)
            if args.first&.is_a?(Prism::StringNode) && args.first.value == "sidekiq"
              replace(args.first, "\"solid_queue\"")
            end
          end

          super
        end
      end
    end
  end
end
