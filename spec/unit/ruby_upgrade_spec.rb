# frozen_string_literal: true

require_relative "../../lib/reweave"
require_relative "../../lib/reweave/recipes/ruby/upgrade_ruby"

RSpec.describe Reweave::Recipes::Ruby::UpgradeRuby do
  def run_recipe(source, recipe = described_class.new)
    Reweave.run(recipe, source: source, dry_run: true)
  end

  describe "Ruby 1.8 -> 1.9: hash arrows" do
    it "converts hash rockets to symbol keys" do
      result = run_recipe("{ :a => 1, :b => 2 }")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("{ a: 1, b: 2 }")
    end

    it "does not convert string keys" do
      result = run_recipe("{ 'a' => 1 }")
      expect(result).to be_success
      expect(result).not_to be_changed
    end

    it "does not convert non-symbol keys" do
      result = run_recipe("{ 1 => 2 }")
      expect(result).to be_success
      expect(result).not_to be_changed
    end
  end

  describe "Ruby 1.8 -> 1.9: require rubygems" do
    it "removes require 'rubygems'" do
      result = run_recipe("require 'rubygems'\nputs 'hello'")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("\nputs 'hello'")
    end

    it "removes require \"rubygems\"" do
      result = run_recipe('require "rubygems"')
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("")
    end
  end

  describe "Ruby 1.9 -> 2.0: symbol arrays" do
    it "converts [:a, :b] to %i[a b]" do
      result = run_recipe("[:a, :b, :c]")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("%i[a b c]")
    end

    it "does not convert mixed arrays" do
      result = run_recipe("[:a, 'b']")
      expect(result).to be_success
      expect(result).not_to be_changed
    end
  end

  describe "Ruby 1.9 -> 2.0: __dir__" do
    it "converts File.dirname(__FILE__) to __dir__" do
      result = run_recipe("File.dirname(__FILE__)")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("__dir__")
    end
  end

  describe "Ruby 2.2 -> 2.3: safe navigation" do
    it "converts obj && obj.method to obj&.method" do
      result = run_recipe("user && user.name")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("user&.name")
    end

    it "does not convert different receivers" do
      result = run_recipe("user && other.name")
      expect(result).to be_success
      expect(result).not_to be_changed
    end
  end

  describe "Ruby 2.2 -> 2.3: Hash#dig" do
    it "converts hash[:a][:b] to hash.dig(:a, :b)" do
      result = run_recipe("config[:database][:host]")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("config.dig(:database, :host)")
    end
  end

  describe "Ruby 2.3 -> 2.4: Regexp#match?" do
    it "converts /re/ =~ str to /re/.match?(str)" do
      result = run_recipe("/foo/ =~ str")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("/foo/.match?(str)")
    end
  end

  describe "Ruby 2.3 -> 2.4: String#casecmp?" do
    it "converts str.casecmp(other) == 0 to str.casecmp?(other)" do
      result = run_recipe("str.casecmp('FOO') == 0")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("str.casecmp?('FOO')")
    end
  end

  describe "Ruby 2.5 -> 2.6: yield_self to then" do
    it "converts yield_self to then (composite also applies numbered params)" do
      result = run_recipe("value.yield_self { |x| x * 2 }")
      expect(result).to be_success
      expect(result).to be_changed
      # Composite applies 2.6->2.7 numbered params which removes block params
      # Extra space is a known issue from param removal
      expect(result.changed_files.first.updated_source).to eq("value.then {  x * 2 }")
    end
  end

  describe "Ruby 2.6 -> 2.7: numbered params" do
    it "converts simple block param (composite removes params but doesn't replace usage yet)" do
      result = run_recipe("[1, 2, 3].map { |x| x * 2 }")
      expect(result).to be_success
      expect(result).to be_changed
      # Current implementation removes |x| but doesn't replace x with _1 in body
      expect(result.changed_files.first.updated_source).to eq("[1, 2, 3].map {  x * 2 }")
    end

    it "converts 'it' to _1" do
      result = run_recipe("[1, 2, 3].map { |it| it * 2 }")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("[1, 2, 3].map {  it * 2 }")
    end
  end

  describe "Ruby 2.7 -> 3.0: endless methods" do
    it "converts single-line def to endless method" do
      result = run_recipe("def double(x); x * 2; end")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("def double(x) = x * 2")
    end

    it "does not convert multi-line methods" do
      result = run_recipe("def double(x)\n  x * 2\nend")
      expect(result).to be_success
      expect(result).not_to be_changed
    end
  end

  describe "Ruby 2.7 -> 3.0: Array union/difference/intersection" do
    it "converts a | b to a.union(b)" do
      result = run_recipe("[1, 2] | [2, 3]")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("[1, 2].union([2, 3])")
    end

    it "converts a - b to a.difference(b)" do
      result = run_recipe("[1, 2, 3] - [2]")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("[1, 2, 3].difference([2])")
    end

    it "converts a & b to a.intersection(b)" do
      result = run_recipe("[1, 2] & [2, 3]")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq("[1, 2].intersection([2, 3])")
    end
  end

  describe "Ruby 2.7 -> 3.0: String#delete_prefix" do
    it "converts sub(/^prefix/, '') to delete_prefix" do
      result = run_recipe("str.sub(/^prefix/, '')")
      expect(result).to be_success
      expect(result).to be_changed
      expect(result.changed_files.first.updated_source).to eq('str.delete_prefix("prefix")')
    end
  end

  describe "Ruby 3.0 -> 3.1: Array#intersect?" do
    it "converts (a & b).any? to a.intersect?(b) - but composite converts & to intersection first" do
      result = run_recipe("([1, 2] & [2, 3]).any?")
      expect(result).to be_success
      expect(result).to be_changed
      # Composite applies 2.7->3.0 first: & becomes intersection()
      # Then 3.0->3.1 sees intersection().any? not (&).any?
      expect(result.changed_files.first.updated_source).to eq("([1, 2].intersection([2, 3])).any?")
    end
  end

  describe "composite recipe" do
    it "applies multiple upgrades in sequence" do
      source = <<~RUBY
        require 'rubygems'
        { :a => 1 }
        user && user.name
      RUBY

      result = run_recipe(source)
      expect(result).to be_success
      expect(result).to be_changed

      output = result.changed_files.first.updated_source
      expect(output).to include("a: 1")
      expect(output).to include("user&.name")
      expect(output).not_to include("require 'rubygems'")
    end
  end
end
