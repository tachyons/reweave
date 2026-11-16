# frozen_string_literal: true

require_relative "../../lib/reweave"
require_relative "../../lib/reweave/recipes/ruby/rename_method"

RSpec.describe Reweave::Recipes::Ruby::RenameMethod do
  let(:recipe) { described_class.new(old_name: "old_method", new_name: "new_method") }

  it "renames a simple method call" do
    source = "user.old_method"
    result = Reweave.run(recipe, source: source, dry_run: true)

    expect(result.success?).to be true
    expect(result.changed?).to be true
    expect(result.changed_files.first.updated_source).to eq("user.new_method")
  end

  it "does not rename unrelated methods" do
    source = "user.other_method"
    result = Reweave.run(recipe, source: source, dry_run: true)

    expect(result.success?).to be true
    expect(result.changed?).to be false
  end

  it "renames with receiver filter" do
    recipe = described_class.new(old_name: "find", new_name: "all", receiver: "User")
    source = "User.find(:all)\nOther.find(:all)"
    result = Reweave.run(recipe, source: source, dry_run: true)

    expect(result.success?).to be true
    expect(result.changed?).to be true
    # Only replaces the method name, not the arguments
    expect(result.changed_files.first.updated_source).to eq("User.all(:all)\nOther.find(:all)")
  end

  it "handles method calls with arguments" do
    source = "user.old_method(1, 2, 3)"
    result = Reweave.run(recipe, source: source, dry_run: true)

    expect(result.success?).to be true
    expect(result.changed_files.first.updated_source).to eq("user.new_method(1, 2, 3)")
  end

  it "handles method calls with block" do
    source = "user.old_method { |x| x }"
    result = Reweave.run(recipe, source: source, dry_run: true)

    expect(result.success?).to be true
    expect(result.changed_files.first.updated_source).to eq("user.new_method { |x| x }")
  end

  it "preserves formatting" do
    source = "  user.old_method  \n"
    result = Reweave.run(recipe, source: source, dry_run: true)

    expect(result.changed_files.first.updated_source).to eq("  user.new_method  \n")
  end
end
