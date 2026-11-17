# frozen_string_literal: true

require_relative "../../lib/reweave"
require_relative "../../lib/reweave/recipes/ruby/declarative_rename"

RSpec.describe Reweave::Recipes::Ruby::DeclarativeRename do
  def run_recipe(source, recipe)
    Reweave.run(recipe, source: source, dry_run: true)
  end

  it "renames a simple method call" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("user.old_method", recipe)

    expect(result).to be_success
    expect(result).to be_changed
    expect(result.changed_files.first.updated_source).to eq("user.new_method")
  end

  it "does not rename unrelated methods" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("user.other_method", recipe)

    expect(result).to be_success
    expect(result).not_to be_changed
  end

  it "renames with receiver filter" do
    recipe = described_class.new(old_name: "find", new_name: "all", receiver: "User")
    result = run_recipe("User.find(:all)\nOther.find(:all)", recipe)

    expect(result).to be_success
    expect(result).to be_changed
    expect(result.changed_files.first.updated_source).to eq("User.all(:all)\nOther.find(:all)")
  end

  it "handles method calls with arguments" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("user.old_method(1, 2, 3)", recipe)

    expect(result).to be_success
    expect(result.changed_files.first.updated_source).to eq("user.new_method(1, 2, 3)")
  end

  it "handles method calls with block" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("user.old_method { |x| x }", recipe)

    expect(result).to be_success
    expect(result.changed_files.first.updated_source).to eq("user.new_method { |x| x }")
  end

  it "preserves formatting" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("  user.old_method  \n", recipe)

    expect(result).to be_success
    expect(result).to be_changed
    expect(result.changed_files.first.updated_source).to eq("  user.new_method  \n")
  end

  it "is idempotent" do
    recipe = described_class.new(old_name: "old_method", new_name: "new_method")
    result = run_recipe("user.old_method", recipe)
    expect(result).to be_changed

    second_result = run_recipe(result.changed_files.first.updated_source, recipe)
    expect(second_result).not_to be_changed
  end

  it "supports multi-file project test" do
    Dir.mktmpdir("reweave_test") do |tmpdir|
      File.write(File.join(tmpdir, "a.rb"), "User.find(1)")
      File.write(File.join(tmpdir, "b.rb"), "User.find(2)")

      recipe = described_class.new(old_name: "find", new_name: "all", receiver: "User")
      result = Reweave.run(recipe, path: tmpdir, dry_run: true)

      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.map(&:path).sort).to eq(["a.rb", "b.rb"].sort)
      expect(result.changed_files.find { |f| f.path.end_with?("a.rb") }.updated_source).to eq("User.all(1)")
      expect(result.changed_files.find { |f| f.path.end_with?("b.rb") }.updated_source).to eq("User.all(2)")
    end
  end
end

RSpec::Matchers.define :be_success do
  match { |result| result.success? }
end

RSpec::Matchers.define :be_changed do
  match { |result| result.changed? }
end
