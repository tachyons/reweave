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
require_relative "upgrade_2_3_to_3_0"
require_relative "upgrade_3_0_to_3_1"
require_relative "upgrade_3_1_to_3_2"
require_relative "upgrade_3_2_to_4_0"
require_relative "upgrade_4_0_to_4_1"
require_relative "upgrade_4_1_to_4_2"
require_relative "upgrade_4_2_to_5_0"
require_relative "upgrade_5_0_to_5_1"
require_relative "upgrade_5_1_to_5_2"
require_relative "upgrade_5_2_to_6_0"
require_relative "upgrade_6_0_to_6_1"
require_relative "upgrade_6_1_to_7_0"
require_relative "upgrade_7_0_to_7_1"
require_relative "upgrade_7_1_to_7_2"
require_relative "upgrade_7_2_to_8_0"
require_relative "upgrade_8_0_to_8_1"

module Reweave
  module Recipes
    module Rails
      # Composite recipe for upgrading Rails applications from 2.3 to 8.1
      class UpgradeRails < CompositeRecipe
        display_name "Upgrade Rails"
        description "Comprehensive Rails upgrade recipe combining all individual migration recipes from 2.3 to 8.1"

        def initialize(**options)
          recipes = [
            # Version upgrades
            Upgrade23To30.new(**options),
            Upgrade30To31.new(**options),
            Upgrade31To32.new(**options),
            Upgrade32To40.new(**options),
            Upgrade40To41.new(**options),
            Upgrade41To42.new(**options),
            Upgrade42To50.new(**options),
            Upgrade50To51.new(**options),
            Upgrade51To52.new(**options),
            Upgrade52To60.new(**options),
            Upgrade60To61.new(**options),
            Upgrade61To70.new(**options),
            Upgrade70To71.new(**options),
            Upgrade71To72.new(**options),
            Upgrade72To80.new(**options),
            Upgrade80To81.new(**options),
            # Specific feature migrations
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
