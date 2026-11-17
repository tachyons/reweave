# frozen_string_literal: true

require_relative "../../lib/reweave"
require_relative "../../lib/reweave/recipes/rails/update_rails_routes"

RSpec.describe "Semantic analysis on ordinary Ruby" do
  # Regression: TypeCollector used stale Prism APIs (BlockParametersNode#parameters#parameters,
  # IfNode#then_clause/#else_clause, CaseNode#when_clauses, Prism::LiteralNode) and the
  # disk cache recursed forever on self-referential class types. Any of these crashed
  # analysis before a single file was scanned, so every `reweave run <recipe>` failed.
  let(:recipe) { Reweave::Recipes::Rails::UpdateRailsRoutes.new }

  it "runs a recipe over a project containing blocks, conditionals, and case statements" do
    source = <<~RUBY
      class Routes
        def draw(mapper)
          mapper.each { |route, opts| route.path if opts }
          if mapper.nil?
            nil
          elsif mapper.empty?
            false
          else
            mapper.first
          end
          case mapper.size
          when 0 then "none"
          when 1 then "one"
          else "many"
          end
        end

        def self.build
          new
        end
      end
    RUBY

    Dir.mktmpdir("reweave_semantic_run") do |root|
      File.write(File.join(root, "routes.rb"), source)

      result = Reweave.run(recipe, path: root, dry_run: true)

      expect(result.success?).to be true
      expect(result.error).to be_nil
      expect(result.stats[:files_scanned]).to eq(1)
      expect(result.stats[:recipes_executed]).to eq(1)
    end
  end
end
