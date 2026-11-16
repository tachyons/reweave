# frozen_string_literal: true

require_relative "../../../reweave/recipe/composite_recipe"
require_relative "replace_deprecated_find"
require_relative "update_active_record"
require_relative "update_rails_routes"
require_relative "update_configuration"
require_relative "solid_queue_migration"
require_relative "solid_cache_migration"
require_relative "active_job_continuations"
require_relative "remove_deprecated_gems"
require_relative "controller_markdown_rendering"

module Reweave
  module Recipes
    module Rails
      # Composite recipe for upgrading Rails applications
      class UpgradeRails < CompositeRecipe
        display_name "Upgrade Rails"
        description "Comprehensive Rails upgrade recipe combining all individual migration recipes"

        def initialize(**options)
          recipes = [
            ReplaceDeprecatedFind.new(**options),
            UpdateActiveRecord.new(**options),
            UpdateRailsRoutes.new(**options),
            UpdateConfiguration.new(**options),
            SolidQueueMigration.new(**options),
            SolidCacheMigration.new(**options),
            ActiveJobContinuations.new(**options),
            RemoveDeprecatedGems.new(**options),
            ControllerMarkdownRendering.new(**options)
          ]
          super(recipes, **options)
        end
      end
    end
  end
end
