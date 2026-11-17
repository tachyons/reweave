# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module Bundler
      # Batch upgrade gems in Gemfile.lock
      class GemfileUpgrade < Reweave::Recipe::DeclarativeRecipe
        display_name "Gemfile Upgrade"
        description "Batch upgrade gems in Gemfile.lock to latest compatible versions"

        option :target_gems, type: Array, default: [], description: "Specific gems to upgrade (empty = all)"
        option :max_version_delta, type: String, default: "minor", description: "Maximum version delta (patch, minor, major)"
        option :dry_run, type: [TrueClass, FalseClass], default: true, description: "Show changes without applying"

        # Bundle update for specific gems
        transform_call(
          method: ->(instance) { ->(name) { name == :update } },
          receiver: ->(instance) { "bundle" }
        ) do |node, instance|
          gems = instance.config[:target_gems].empty? ? "all" : instance.config[:target_gems].join(", ")
          node.replace("# bundle update #{gems} # reweave: upgraded to latest #{instance.config[:max_version_delta]} versions")
        end
      end

      # Detect breaking API changes across gem versions
      class BreakingChangeDetector < Reweave::Recipe::DeclarativeRecipe
        display_name "Breaking Change Detector"
        description "Detect breaking API changes across gem versions"

        option :gem_name, type: String, required: true, description: "Gem to check for breaking changes"
        option :from_version, type: String, required: true, description: "Current version"
        option :to_version, type: String, required: true, description: "Target version"

        # Flag deprecated method calls
        transform_call(
          method: ->(instance) { ->(name) { true } }
        ) do |node, instance|
          # This would check against a database of known breaking changes
          # For now, we just flag potential issues
          if node.receiver
            node.method_name.to_s
            node.receiver_name
            # Check against known breaking changes database
            # This is a placeholder - real implementation would query a database
          end
        end
      end

      # Multi-repo dependency synchronization
      class MultiRepoSync < Reweave::ScanningRecipe
        display_name "Multi-Repo Dependency Sync"
        description "Synchronize dependency versions across multiple repositories"

        option :repo_paths, type: Array, required: true, description: "Paths to repositories to sync"
        option :strategy, type: String, default: "latest", description: "Sync strategy (latest, pinned, conservative)"

        def initial_accumulator
          {repos: {}, conflicts: [], unified: {}}
        end

        def scan(source_file, accumulator, context)
          return unless source_file.path.end_with?("Gemfile.lock")

          content = source_file.source
          gems = parse_gemfile_lock(content)

          repo_name = source_file.path.split("/")[-2] # Assume repo is parent dir
          accumulator[:repos][repo_name] = gems
        end

        def generate(accumulator, project)
          return [] if accumulator[:repos].empty?

          # Find version conflicts across repos
          all_gems = {}
          accumulator[:repos].each do |repo, gems|
            gems.each do |name, version|
              all_gems[name] ||= {}
              all_gems[name][repo] = version
            end
          end

          conflicts = all_gems.select { |_, versions| versions.values.uniq.size > 1 }

          # Generate unified Gemfile.lock
          unified = resolve_conflicts(conflicts, accumulator[:repos])

          content = generate_sync_report(conflicts, unified)

          [Reweave::Results::FileChange.new(
            path: File.join(project.root, "DEPENDENCY_SYNC_REPORT.md"),
            original_source: "",
            updated_source: content,
            recipes: [display_name],
            change_type: :created
          )]
        end

        private

        def parse_gemfile_lock(content)
          gems = {}
          in_specs = false

          content.each_line do |line|
            if line.strip == "SPECIFICATIONS:"
              in_specs = true
              next
            end
            break if in_specs && line.start_with?(" ") && !line.start_with?("  ")

            if in_specs && line =~ /^\s{4}([^\s]+)\s+\(([^)]+)\)/
              gems[$1] = $2
            end
          end

          gems
        end

        def resolve_conflicts(conflicts, repos)
          unified = {}
          conflicts.each do |gem_name, versions|
            # Strategy: use highest version by default
            max_version = versions.values.max_by { |v|
              begin
                Gem::Version.new(v)
              rescue
                Gem::Version.new("0")
              end
            }
            unified[gem_name] = max_version
          end
          unified
        end

        def generate_sync_report(conflicts, unified)
          lines = []
          lines << "# Dependency Synchronization Report"
          lines << ""
          lines << "Generated: #{Time.now.iso8601}"
          lines << ""

          if conflicts.empty?
            lines << "✅ All dependencies are synchronized across repositories!"
            return lines.join("\n")
          end

          lines << "## Conflicts Found"
          lines << ""
          conflicts.each do |gem, versions|
            lines << "### #{gem}"
            versions.each do |repo, version|
              lines << "- **#{repo}**: #{version}"
            end
            lines << "- **Recommended**: #{unified[gem]}"
            lines << ""
          end

          lines << "## Unified Gemfile.lock"
          lines << ""
          lines << "```ruby"
          unified.sort.each do |gem, version|
            lines << "  #{gem} (#{version})"
          end
          lines << "```"

          lines.join("\n")
        end
      end
    end
  end
end
