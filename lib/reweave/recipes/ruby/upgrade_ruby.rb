# frozen_string_literal: true

require_relative "../../../reweave/recipe/composite_recipe"
require_relative "upgrade_1_8_to_1_9"
require_relative "upgrade_1_9_to_2_0"
require_relative "upgrade_2_0_to_2_1"
require_relative "upgrade_2_1_to_2_2"
require_relative "upgrade_2_2_to_2_3"
require_relative "upgrade_2_3_to_2_4"
require_relative "upgrade_2_4_to_2_5"
require_relative "upgrade_2_5_to_2_6"
require_relative "upgrade_2_6_to_2_7"
require_relative "upgrade_2_7_to_3_0"
require_relative "upgrade_3_0_to_3_1"
require_relative "upgrade_3_1_to_3_2"
require_relative "upgrade_3_2_to_3_3"
require_relative "upgrade_3_3_to_4_0"

module Reweave
  module Recipes
    module Ruby
      # Composite recipe for upgrading Ruby versions from 1.8 to 4.0
      class UpgradeRuby < CompositeRecipe
        display_name "Upgrade Ruby"
        description "Comprehensive Ruby upgrade recipe combining all version migration recipes from 1.8 to 4.0"

        def initialize(**options)
          recipes = [
            Upgrade18To19.new(**options),
            Upgrade19To20.new(**options),
            Upgrade20To21.new(**options),
            Upgrade21To22.new(**options),
            Upgrade22To23.new(**options),
            Upgrade23To24.new(**options),
            Upgrade24To25.new(**options),
            Upgrade25To26.new(**options),
            Upgrade26To27.new(**options),
            Upgrade27To30.new(**options),
            Upgrade30To31.new(**options),
            Upgrade31To32.new(**options),
            Upgrade32To33.new(**options),
            Upgrade33To40.new(**options)
          ]
          super(recipes, **options)
        end
      end
    end
  end
end
