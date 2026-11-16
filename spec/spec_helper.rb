# frozen_string_literal: true

require "reweave"
require "tempfile"
require "fileutils"

module Reweave
  module Testing
    class RecipeTester
      attr_reader :recipe, :source, :result, :project_files

      def initialize(recipe)
        @recipe = recipe
        @project_files = {}
      end

      def rewrite(source)
        @source = source
        @result = Reweave.run(@recipe, source: source, dry_run: true)
        self
      end

      def rewrite_project(&block)
        instance_eval(&block) if block_given?
        @result = Reweave.run(@recipe, path: @project_root, dry_run: true)
        self
      end

      def file(path, content)
        @project_files[path] = content
        @project_root ||= Dir.mktmpdir("reweave_test")
        full_path = File.join(@project_root, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, content)
        self
      end

      def expect_output(expected)
        raise "No source provided. Call rewrite(source) first." unless @result
        expect(@result.success?).to be true
        expect(@result.changed?).to be true
        expect(@result.changed_files.first.updated_source).to eq(expected)
        self
      end

      def expect_no_change
        raise "No source provided. Call rewrite(source) first." unless @result
        expect(@result.success?).to be true
        expect(@result.changed?).to be false
        self
      end

      def expect_diagnostic(message)
        raise "No source provided. Call rewrite(source) first." unless @result
        expect(@result.diagnostics.any? { |d| d.message.include?(message) }).to be true
        self
      end

      def expect_idempotent
        raise "No source provided. Call rewrite(source) first." unless @result
        return self unless @result.changed?

        second_result = Reweave.run(@recipe, source: @result.changed_files.first.updated_source, dry_run: true)
        expect(second_result.changed_files.first.updated_source).to eq(@result.changed_files.first.updated_source)
        self
      end

      def expect_file(path)
        raise "No project files. Call rewrite_project first." unless @result
        file_change = @result.changed_files.find { |f| f.path.end_with?(path) }
        expect(file_change).not_to be_nil
        expected = yield
        expect(file_change.updated_source).to eq(expected)
        self
      end
    end

    def self.recipe_tester(recipe)
      RecipeTester.new(recipe)
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.include Module.new {
    def test_recipe(recipe_class, **options)
      recipe = recipe_class.new(**options)
      Reweave::Testing.recipe_tester(recipe)
    end
  }
end