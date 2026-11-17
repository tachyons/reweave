# frozen_string_literal: true

require "reweave"

namespace :reweave do
  desc "Run a reweave recipe (usage: rake reweave:run[recipe_name,options])"
  task :run, [:recipe_name, :options] do |_t, args|
    recipe_name = args[:recipe_name]
    options = parse_options(args[:options])

    abort("Usage: rake reweave:run[recipe_name,options]") unless recipe_name

    Reweave::REGISTRY.discover_recipes
    recipe_class = Reweave::REGISTRY.get(recipe_name)
    abort("Recipe not found: #{recipe_name}") unless recipe_class

    recipe = recipe_class.new(**options)
    result = Reweave.run(recipe, path: ".", dry_run: false)

    puts result.summary
    exit(result.success? ? 0 : 1)
  end

  desc "Validate a reweave config file (usage: rake reweave:validate[config_file])"
  task :validate, [:config_file] do |_t, args|
    config_file = args[:config_file]
    abort("Usage: rake reweave:validate[config_file]") unless config_file

    Reweave::REGISTRY.discover_recipes
    config = Reweave::Config.load(config_file)
    puts "✓ Config is valid"
    recipe = Reweave::Config.build_recipe(config)
    puts "Recipe: #{recipe.class.name}"
    puts "Display: #{recipe.display_name}"
  end

  desc "List available recipes"
  task :recipes do
    Reweave::REGISTRY.discover_recipes
    puts "Available recipes:"
    Reweave::REGISTRY.names.each do |name|
      recipe_class = Reweave::REGISTRY.get(name)
      puts "  #{name} - #{recipe_class.display_name}"
    end
  end

  desc "Show recipe details (usage: rake reweave:describe[recipe_name])"
  task :describe, [:recipe_name] do |_t, args|
    recipe_name = args[:recipe_name]
    abort("Usage: rake reweave:describe[recipe_name]") unless recipe_name

    Reweave::REGISTRY.discover_recipes
    recipe_class = Reweave::REGISTRY.get(recipe_name)
    abort("Recipe not found: #{recipe_name}") unless recipe_class

    recipe = recipe_class.allocate
    puts "Name: #{recipe_name}"
    puts "Display: #{recipe.display_name}"
    puts "Description: #{recipe.description}"
    puts "Options:"
    recipe.class.options.each do |name, opt|
      req = opt.required? ? " (required)" : ""
      def_str = opt.default ? " [default: #{opt.default.inspect}]" : ""
      puts "  #{name}: #{opt.type}#{req}#{def_str}"
      puts "    #{opt.description}" if opt.description
    end
  end

  desc "Run reweave in dry-run mode (usage: rake reweave:dry_run[recipe_name,options])"
  task :dry_run, [:recipe_name, :options] do |_t, args|
    recipe_name = args[:recipe_name]
    options = parse_options(args[:options])

    abort("Usage: rake reweave:dry_run[recipe_name,options]") unless recipe_name

    Reweave::REGISTRY.discover_recipes
    recipe_class = Reweave::REGISTRY.get(recipe_name)
    abort("Recipe not found: #{recipe_name}") unless recipe_class

    recipe = recipe_class.new(**options)
    result = Reweave.run(recipe, path: ".", dry_run: true)

    puts result.summary
    if result.changed?
      puts "\n--- Diffs ---"
      puts result.diffs
    end
    exit(result.success? ? 0 : 1)
  end

  private

  def parse_options(options_str)
    return {} unless options_str

    options = {}
    options_str.split(",").each do |pair|
      key, value = pair.split("=")
      options[key.to_sym] = value
    end
    options
  end
end
