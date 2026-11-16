# frozen_string_literal: true

require_relative "../../lib/reweave"
require_relative "../../lib/reweave/recipes/ruby/rename_method"
require_relative "../../lib/reweave/recipes/ruby/upgrade_1_8_to_1_9"
require_relative "../../lib/reweave/recipes/ruby/modernize_syntax"
require_relative "../../lib/reweave/recipes/rails/solid_queue_migration"
require_relative "../../lib/reweave/recipes/rails/solid_cache_migration"

RSpec.describe "RecipeHelpers integration" do
  def run_recipe(source, recipe)
    Reweave.run(recipe, source: source, dry_run: true)
  end

  describe "replace_method_name helper" do
    it "renames method calls using the helper" do
      recipe = Reweave::Recipes::Ruby::RenameMethod.new(old_name: "old_method", new_name: "new_method")
      result = run_recipe("user.old_method", recipe)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("user.new_method")
    end
  end

  describe "replace_config_value helper" do
    it "replaces config value in solid_queue_migration" do
      recipe = Reweave::Recipes::Rails::SolidQueueMigration.new
      result = run_recipe("config.active_job.queue_adapter = :sidekiq", recipe)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("config.active_job.queue_adapter = :solid_queue")
    end

    it "replaces config value with string in solid_queue_migration" do
      recipe = Reweave::Recipes::Rails::SolidQueueMigration.new
      result = run_recipe('config.active_job.queue_adapter = "sidekiq"', recipe)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq('config.active_job.queue_adapter = "solid_queue"')
    end

    it "replaces multiple config values in solid_cache_migration" do
      recipe = Reweave::Recipes::Rails::SolidCacheMigration.new

      result1 = run_recipe("config.cache_store = :redis_cache_store", recipe)
      expect(result1).to be_changed
      expect(result1.changed_files.first.updated_source).to eq("config.cache_store = :solid_cache_store")

      result2 = run_recipe("config.cache_store = :mem_cache_store", recipe)
      expect(result2).to be_changed
      expect(result2.changed_files.first.updated_source).to eq("config.cache_store = :solid_cache_store")

      result3 = run_recipe("config.cache_store = :memory_store", recipe)
      expect(result3).to be_changed
      expect(result3.changed_files.first.updated_source).to eq("config.cache_store = :solid_cache_store")
    end
  end

  describe "convert_hash_rocket_to_symbol_key helper" do
    it "converts hash rockets in upgrade_1_8_to_1_9" do
      recipe = Reweave::Recipes::Ruby::Upgrade18To19.new(convert_hash_arrows: true)
      result = run_recipe("{ :a => 1, :b => 2 }", recipe)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("{ a: 1, b: 2 }")
    end

    it "converts hash rockets in modernize_syntax" do
      recipe = Reweave::Recipes::Ruby::ModernizeSyntax.new(convert_hash_arrows: true)
      result = run_recipe("{ :a => 1 }", recipe)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("{ a: 1 }")
    end
  end

  describe "first_arg and string_node? helpers" do
    it "removes require rubygems using helpers" do
      recipe = Reweave::Recipes::Ruby::Upgrade18To19.new(remove_require_rubygems: true)
      result = run_recipe("require 'rubygems'\nputs 'hello'", recipe)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("\nputs 'hello'")
    end
  end
end
