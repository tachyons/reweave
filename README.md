# Reweave

> Automated code refactoring and modernization for Ruby. Inspired by OpenRewrite, built for Ruby.

Reweave is a native Ruby source code transformation framework that enables safe, composable, and repeatable code transformations across entire codebases. It uses the [Prism](https://github.com/ruby/prism) parser for accurate Ruby syntax analysis and provides a lossless source editing engine.

## Features

- **Native Ruby** — No JVM, no JRuby, no external runtimes
- **Lossless editing** — Preserves formatting, comments, and whitespace
- **Composable recipes** — Build complex transformations from simple parts
- **Project-wide execution** — Transform entire repositories safely
- **Prism-powered** — Uses Ruby's official parser for 100% syntax compatibility
- **Strong testing** — Built-in RSpec testing DSL for recipes
- **CLI included** — Run transformations from the command line
- **Declarative DSL** — Write recipes without Prism internals
- **Type inference** — Cross-file type analysis for context-aware transformations
- **Semantic cache** — Cross-recipe type sharing with automatic invalidation
- **Skills CLI** — Discover and install recipe packs for common migrations

## Installation

```bash
gem install reweave
```

Or add to your Gemfile:

```ruby
gem "reweave"
```

## Quick Start

Create a recipe:

```ruby
# rename_deprecated_method.rb
require "reweave"

class RenameDeprecatedMethod < Reweave::Recipe
  display_name "Rename deprecated method"
  description "Renames old_method to new_method."

  option :old_name, type: String, required: true
  option :new_name, type: String, required: true

  def get_visitor(context)
    RenameDeprecatedMethodVisitor.new(context, old_name: config[:old_name], new_name: config[:new_name])
  end
end

class RenameDeprecatedMethodVisitor < Reweave::Visitor::RubyVisitor
  def initialize(context, old_name:, new_name:)
    super(context, nil)
    @old_name = old_name.to_sym
    @new_name = new_name
  end

  def visit(source_file)
    @source_file = source_file
    visit(source_file.root)
    edits
  end

  def visit_call_node(node)
    return unless node.name == @old_name
    replace_location(node.message_loc, @new_name) if node.message_loc
  end
end
```

Or use the **declarative DSL** (recommended for new recipes):

```ruby
class DeclarativeRename < Reweave::Recipe::DeclarativeRecipe
  display_name "Declarative rename method"
  description "Renames a method call using the declarative DSL"

  option :old_name, type: String, required: true
  option :new_name, type: String, required: true
  option :receiver, type: String, required: false

  transform_call(
    method: ->(instance) { ->(name) { name.to_s == instance.config[:old_name] } },
    receiver: ->(instance) { instance.config[:receiver] },
    args: ->(instance) { ->(node) { true } }
  ) do |node, instance|
    node.replace(node.receiver ? "#{node.receiver_name}.#{instance.config[:new_name]}" : instance.config[:new_name])
  end
end
```

Run it:

```bash
# Dry run (shows diffs, doesn't modify files)
reweave run RenameDeprecatedMethod --old-name old_method --new-name new_method --dry-run

# Apply changes
reweave run RenameDeprecatedMethod --old-name old_method --new-name new_method
```

Or programmatically:

```ruby
require "reweave"

result = Reweave.run(
  RenameDeprecatedMethod.new(old_name: "old_method", new_name: "new_method"),
  source: "user.old_method"
)

puts result.changed_files.first.updated_source
# => "user.new_method"
```

## Architecture

Reweave follows OpenRewrite's architecture adapted for Ruby:

```
┌─────────────────────────────────────────────────────┐
│                    Recipe                           │
│  (declarative transformation definition)            │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                   Visitor                           │
│  (traverses Prism AST, collects edits)              │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                   EditSet                           │
│  (validates & applies byte-accurate edits)          │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                   Engine                            │
│  (orchestrates execution, cycles, project mgmt)     │
└─────────────────────────────────────────────────────┘
```

## Core Concepts

### Recipes

Recipes define transformations. They can be:

- **Transformation recipes** — Modify source code
- **Scanning recipes** — Analyze multiple files, accumulate data
- **Composite recipes** — Compose multiple recipes

### Declarative DSL

The declarative DSL lets you write recipes without knowing Prism internals:

```ruby
class MyRecipe < Reweave::Recipe::DeclarativeRecipe
  option :option_name, type: String, required: true

  # Transform method calls
  transform_call(
    method: :method_name,
    receiver: "ClassName",
    args: ->(instance) { ->(node) { true } }
  ) do |node, instance|
    node.replace("new_code")
  end

  # Transform method definitions
  transform_def(name: :initialize) do |node, instance|
    # ...
  end

  # Transform class definitions
  transform_class(name: "User") do |node, instance|
    # ...
  end

  # Transform constant references
  transform_constant(name: "OLD_CONSTANT") do |node, instance|
    # ...
  end

  # Transform hash nodes
  transform_hash do |node, instance|
    # ...
  end

  # Transform lambda nodes
  transform_lambda do |node, instance|
    # ...
  end

  # Transform block parameters
  transform_block_params do |node, instance|
    # ...
  end
end
```

### Visitors

For advanced use cases, visitors traverse the Prism AST and collect edits:

```ruby
class MyVisitor < Reweave::Visitor::RubyVisitor
  def visit_call_node(node)
    replace(node, "new_code")
    delete(node)
    insert_before(node, "prefix")
    insert_after(node, "suffix")
    super
  end
end
```

### Edits

Edits are immutable, byte-accurate operations validated before application:

- Offset bounds checking
- Overlap detection
- UTF-8 boundary validation
- Conflict resolution

### Engine

The engine handles:
- File discovery
- Sequential recipe execution
- Multi-cycle convergence
- Dry-run mode
- Result aggregation

### Semantic Analysis

Reweave includes cross-file semantic analysis:

- **Symbol table** — Cross-file method/constant index
- **Type inference** — Variable, method, and constant type inference
- **Type table** — Stores inferred types for classes, methods, variables
- **Semantic cache** — File-based caching with automatic invalidation

```ruby
# Use type information in recipes
result.type_table.class_type("User")
result.type_table.method_signature(:find_by_email)
```

### Skills CLI

Manage recipe packs for common migrations:

```bash
# List available skills
reweave skills available

# Install a skill pack
reweave skills install rails-migrations

# List installed skills
reweave skills list

# Run recipes from installed skills
reweave run UpgradeRails --dry-run
```

## Built-in Recipes

### Ruby Core
- `DeclarativeModernizeSyntax` — Hash rockets, lambda arrows, block args
- `DeclarativeRename` — Rename method calls across codebase
- `RemoveUnusedMethods` — Remove uncalled methods
- `FindMethodCalls` — Scan and report method calls

### Ruby Version Upgrades
- `Upgrade18To19` — Hash rockets, `require 'rubygems'`, block args
- `Upgrade19To20` — Symbol arrays (`%i`), `__dir__`
- `Upgrade20To21` — `Hash#to_h`, required kwargs
- `Upgrade21To22` — Symbol GC, `Kernel#itself`
- `Upgrade22To23` — Safe navigation (`&.`), `Hash#dig`
- `Upgrade23To24` — `Regexp#match?`, `String#casecmp?`, `Hash#compact`
- `Upgrade24To25` — `yield_self`/`then`, `Hash#slice`
- `Upgrade25To26` — Endless ranges, `then` alias
- `Upgrade26To27` — Numbered params (`_1`), beginless ranges
- `Upgrade27To30` — Pattern matching, endless methods, `Array#union/difference/intersection`, `Hash#except`, `String#delete_prefix`
- `Upgrade30To31` — `Array#intersect?`
- ... up to Ruby 4.0

### Rails Migrations
- `ReplaceDeprecatedFind` — `find(:all)` → `all`, dynamic finders
- `UpdateActiveRecord` — `update_attributes` → `update`, `destroy_all` conditions
- `UpdateRailsRoutes` — `match` → HTTP verbs
- `UpdateConfiguration` — Deprecated config options
- `SolidQueueMigration` — ActiveJob → SolidQueue
- `SolidCacheMigration` — Cache store → SolidCache
- `ActiveJobContinuations` — `stopping?` checks
- `RemoveDeprecatedGems` — Remove `spring`, `listen`, etc.
- `ControllerMarkdownRendering` — `render inline` → `render markdown:`

### Rails Version Upgrades
- `Upgrade23To30` through `Upgrade80To81` — Version-specific migrations

## Skills System

Pre-packaged recipe collections for common migrations:

```bash
# List available skills
reweave skills available

# Install a skill
reweave skills install rails-migrations

# List installed
reweave skills list

# Run skill recipes
reweave run UpgradeRails --dry-run
```

Pre-packaged skills:
| Skill | Category | Recipes | Description |
|-------|----------|---------|-------------|
| `rails-migrations` | rails | 10 | Upgrade Rails 2.3 → 8.1 |
| `ruby-upgrades` | ruby | 15 | Upgrade Ruby 1.8 → 4.0 |
| `modernize-syntax` | ruby | 1 | Hash rockets, lambdas, block args |
| `code-cleanup` | ruby | 3 | Remove unused, find calls, rename |
| `security-patches` | security | 0 | CVE/ vulnerability fixes (placeholder) |
| `dependency-management` | bundler | 0 | Gemfile upgrades (placeholder) |

## Testing

Reweave includes a first-class testing DSL:

```ruby
RSpec.describe RenameDeprecatedMethod do
  def run_recipe(source, recipe = described_class.new)
    Reweave.run(recipe, source: source, dry_run: true)
  end

  it "renames a simple method call" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("user.old_method", recipe)

    expect(result).to be_success
    expect(result).to be_changed
    expect(result.changed_files.first.updated_source).to eq("user.new_method")
  end

  it "handles multiple calls" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("a.old_method; b.old_method", recipe)

    expect(result).to be_changed
    expect(result.changed_files.first.updated_source).to eq("a.new_method; b.new_method")
  end
end
```

## Requirements

- Ruby 3.2+
- Prism 1.0+

## License

MIT License - see LICENSE file for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

**Reweave** — Bringing OpenRewrite's power to the Ruby ecosystem.