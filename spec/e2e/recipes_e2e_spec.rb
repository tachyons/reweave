# frozen_string_literal: true

require_relative "../../lib/reweave"

# End-to-end suite: runs the real engine (file discovery + semantic analysis +
# recipe execution) over fixture codebases under spec/fixtures.
#
# Fixtures stay pristine: runs are dry-run and we assert on the in-memory
# change set instead of files on disk.

FIXTURE_ROOT = File.expand_path("../fixtures", __dir__)
RAILS_APP = File.join(FIXTURE_ROOT, "rails_app")
RUBY_APP = File.join(FIXTURE_ROOT, "ruby_app")

# Recipes that cannot be instantiated without required options.
REQUIRED_OPTIONS = {
  "Reweave::Recipes::Bundler::BreakingChangeDetector" => {gem_name: "rails", from_version: "6.0.0", to_version: "7.0.0"},
  "Reweave::Recipes::Bundler::MultiRepoSync" => {repo_paths: [RAILS_APP]},
  "Reweave::Recipes::Ruby::DeclarativeRename" => {old_name: "find", new_name: "lookup"}
}.freeze

# Recipes excluded from the smoke loop.
SKIP_SMOKE = {
  # Hits the network (Ruby advisory databases) — not hermetic.
  "Reweave::Recipes::Security::CVEDatabaseScan" => "requires network access",
  # Composite passes a visitor where the engine expects a recipe, and
  # FindMethodDefinitions assigns @accumulator on a frozen recipe. Both crash
  # on every run. https://github.com/tachyons/reweave/issues/46
  "Reweave::Recipes::Ruby::RemoveUnusedMethods" => "broken composite wiring, see #46",
  "Reweave::Recipes::Ruby::RemoveUnusedMethods::FindMethodDefinitions" => "mutates frozen recipe, see #46"
}.freeze

RSpec.describe "Recipe e2e over fixture codebases", :e2e do
  Reweave::REGISTRY.discover_recipes

  def run_on_fixtures(recipe)
    [RAILS_APP, RUBY_APP].map { |root| Reweave.run(recipe, path: root, dry_run: true) }
  end

  it "registers a healthy number of recipes" do
    expect(Reweave::REGISTRY.all.size).to be > 40
  end

  describe "smoke: every recipe runs without crashing" do
    Reweave::REGISTRY.all.each do |recipe_class|
      next if SKIP_SMOKE.key?(recipe_class.name)

      it "#{recipe_class.name} succeeds on both fixtures" do
        recipe = recipe_class.new(**(REQUIRED_OPTIONS[recipe_class.name] || {}))
        results = run_on_fixtures(recipe)

        results.each do |result|
          expect(result.error).to be_nil
          expect(result).to be_success
          expect(result.stats[:recipes_executed]).to be >= 1
        end
      end
    end
  end

  describe "Rails recipes produce real transformations" do
    it "UpdateRailsRoutes converts match to get/post" do
      result = Reweave.run(
        Reweave::Recipes::Rails::UpdateRailsRoutes.new,
        path: RAILS_APP, dry_run: true
      )
      routes = result.changed_files.find { |f| f.path.end_with?("routes.rb") }

      expect(routes).not_to be_nil
      expect(routes.updated_source).to include(%(get ':controller(/:action(/:id))'))
      expect(routes.updated_source).to include(%(post "/logout"))
      expect(routes.updated_source).not_to match(/^\s*match\s/)
    end

    it "SolidQueueMigration replaces sidekiq adapter" do
      result = Reweave.run(
        Reweave::Recipes::Rails::SolidQueueMigration.new,
        path: RAILS_APP, dry_run: true
      )
      config = result.changed_files.find { |f| f.path.end_with?("application.rb") }

      expect(config.updated_source).to include("config.active_job.queue_adapter = :solid_queue")
    end

    it "SolidCacheMigration replaces cache store" do
      result = Reweave.run(
        Reweave::Recipes::Rails::SolidCacheMigration.new,
        path: RAILS_APP, dry_run: true
      )
      config = result.changed_files.find { |f| f.path.end_with?("application.rb") }

      expect(config.updated_source).to include("config.cache_store = :solid_cache_store")
    end

    it "ReplaceDeprecatedFind modernizes finders" do
      result = Reweave.run(
        Reweave::Recipes::Rails::ReplaceDeprecatedFind.new,
        path: RAILS_APP, dry_run: true
      )
      models = result.changed_files.find { |f| f.path.end_with?("user_manager.rb") }

      expect(models.updated_source).to include("User.all")
      expect(models.updated_source).to include("User.where(name: name).first")
    end
  end

  describe "Ruby recipes produce real transformations" do
    it "DeclarativeModernizeSyntax converts hash rockets" do
      result = Reweave.run(
        Reweave::Recipes::Ruby::DeclarativeModernizeSyntax.new,
        path: RUBY_APP, dry_run: true
      )
      hash_file = result.changed_files.find { |f| f.path.end_with?("hash_syntax.rb") }

      expect(hash_file).not_to be_nil
      expect(hash_file.updated_source).to include("OPTIONS = { a: 1, b: 2 }")
      expect(hash_file.updated_source).to include("{ x: OPTIONS[:a], y: 2 }")
    end

    it "DeclarativeRename renames calls across files" do
      recipe = Reweave::Recipes::Ruby::DeclarativeRename.new(old_name: "find", new_name: "lookup")
      result = Reweave.run(recipe, path: RAILS_APP, dry_run: true)
      jobs = result.changed_files.find { |f| f.path.end_with?("report_job.rb") }

      expect(jobs.updated_source).to include("User.lookup(user_id)")
    end
  end
end
