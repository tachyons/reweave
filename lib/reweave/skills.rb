# frozen_string_literal: true

require "json"
require "fileutils"
require "open-uri"

module Reweave
  module Skills
    SKILLS_DIR = File.expand_path("~/.config/reweave/skills")
    REGISTRY_URL = "https://raw.githubusercontent.com/tachyons/reweave-skills/main/registry.json"

    # Predefined skill catalog (can be extended from registry)
    SKILL_CATALOG = {
      "rails-migrations" => {
        name: "rails-migrations",
        description: "Rails migration recipes for upgrading from 2.3 to 8.1",
        category: "rails",
        recipes: [
          "ReplaceDeprecatedFind",
          "UpdateActiveRecord",
          "UpdateRailsRoutes",
          "UpdateConfiguration",
          "SolidQueueMigration",
          "SolidCacheMigration",
          "ActiveJobContinuations",
          "RemoveDeprecatedGems",
          "ControllerMarkdownRendering",
          "UpgradeRails"
        ],
        version: "1.0.0"
      },
      "ruby-upgrades" => {
        name: "ruby-upgrades",
        description: "Ruby version upgrade recipes from 1.8 to 4.0",
        category: "ruby",
        recipes: [
          "Upgrade18To19",
          "Upgrade19To20",
          "Upgrade20To21",
          "Upgrade21To22",
          "Upgrade22To23",
          "Upgrade23To24",
          "Upgrade24To25",
          "Upgrade25To26",
          "Upgrade26To27",
          "Upgrade27To30",
          "Upgrade30To31",
          "Upgrade31To32",
          "Upgrade32To33",
          "Upgrade33To40",
          "UpgradeRuby"
        ],
        version: "1.0.0"
      },
      "modernize-syntax" => {
        name: "modernize-syntax",
        description: "Modernize Ruby syntax (hash rockets, lambda arrows, block args)",
        category: "ruby",
        recipes: ["DeclarativeModernizeSyntax"],
        version: "1.0.0"
      },
      "code-cleanup" => {
        name: "code-cleanup",
        description: "Remove unused methods, find method calls, rename methods",
        category: "ruby",
        recipes: [
          "RemoveUnusedMethods",
          "FindMethodCalls",
          "DeclarativeRename"
        ],
        version: "1.0.0"
      },
      "security-patches" => {
        name: "security-patches",
        description: "Security patch recipes for common vulnerabilities",
        category: "security",
        recipes: [
          "CVEDatabaseScan",
          "VulnerableMethods",
          "PatchVerification"
        ],
        version: "1.0.0"
      },
      "dependency-management" => {
        name: "dependency-management",
        description: "Batch Gemfile/Gemfile.lock dependency upgrades and synchronization",
        category: "bundler",
        recipes: [
          "GemfileUpgrade",
          "BreakingChangeDetector",
          "MultiRepoSync"
        ],
        version: "1.0.0"
      },
      "static-analysis" => {
        name: "static-analysis",
        description: "Static analysis auto-fix and RuboCop integration",
        category: "static-analysis",
        recipes: [
          "RuboCopMapping",
          "AutoFix",
          "CustomCops"
        ],
        version: "1.0.0"
      }
    }.freeze

    class << self
      def list_installed
        ensure_skills_dir
        installed = Dir.glob(File.join(SKILLS_DIR, "*.json")).map do |file|
          JSON.parse(File.read(file))
        end
        if installed.empty?
          puts "No skills installed."
        else
          puts "Installed skills:"
          installed.each do |skill|
            puts "  #{skill["name"]} (#{skill["version"]}) - #{skill["description"]}"
            puts "    Recipes: #{skill["recipes"].join(", ")}" if skill["recipes"]&.any?
          end
        end
      end

      def list_available
        puts "Available skills:"
        SKILL_CATALOG.each do |name, info|
          installed = installed?(name)
          status = installed ? " [INSTALLED]" : ""
          puts "  #{name}#{status}"
          puts "    #{info[:description]}"
          puts "    Category: #{info[:category]}"
          puts "    Recipes: #{info[:recipes].join(", ")}" if info[:recipes]&.any?
        end
      end

      def install(name)
        skill = SKILL_CATALOG[name]
        abort("Skill not found: #{name}. Run 'reweave skills available' to see available skills.") unless skill

        if installed?(name)
          puts "Skill '#{name}' is already installed."
          return
        end

        ensure_skills_dir

        skill_data = {
          name: skill[:name],
          description: skill[:description],
          category: skill[:category],
          recipes: skill[:recipes],
          version: skill[:version],
          installed_at: Time.now.iso8601
        }

        file_path = File.join(SKILLS_DIR, "#{name}.json")
        File.write(file_path, JSON.pretty_generate(skill_data))

        puts "✓ Installed skill: #{name} (#{skill[:version]})"
        puts "  Description: #{skill[:description]}"
        puts "  Recipes: #{skill[:recipes].join(", ")}" if skill[:recipes]&.any?
        puts ""
        puts "You can now use these recipes with 'reweave run <RecipeName>'"
      end

      def remove(name)
        unless installed?(name)
          puts "Skill '#{name}' is not installed."
          return
        end

        file_path = File.join(SKILLS_DIR, "#{name}.json")
        File.delete(file_path)
        puts "✓ Removed skill: #{name}"
      end

      private

      def ensure_skills_dir
        FileUtils.mkdir_p(SKILLS_DIR)
      end

      def installed?(name)
        File.exist?(File.join(SKILLS_DIR, "#{name}.json"))
      end
    end
  end
end
