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

### Visitors

Visitors traverse the Prism AST and collect edits using a mutation API:

```ruby
replace(node, "new_code")
delete(node)
insert_before(node, "prefix")
insert_after(node, "suffix")
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

## Testing

Reweave includes a first-class testing DSL:

```ruby
RSpec.describe RenameDeprecatedMethod do
  it "renames method calls" do
    rewrite("user.old_method")
    expect_output("user.new_method")
  end

  it "handles multiple calls" do
    rewrite("a.old_method; b.old_method")
    expect_output("a.new_method; b.new_method")
  end
end
```

## Built-in Recipes

Coming soon:
- Ruby modernization (hash syntax, keyword args, etc.)
- Rails migrations (deprecated APIs, version upgrades)
- RSpec transformations
- Bundler/Gemfile updates

## Requirements

- Ruby 3.2+
- Prism 1.0+

## License

MIT License - see LICENSE file for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

**Reweave** — Bringing OpenRewrite's power to the Ruby ecosystem.