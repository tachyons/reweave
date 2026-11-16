# frozen_string_literal: true

require_relative "../../lib/reweave"
require_relative "../../lib/reweave/semantic/symbol_table"
require_relative "../../lib/reweave/semantic/symbol_collector"
require_relative "../../lib/reweave/semantic/analyzer"

RSpec.describe Reweave::Semantic::Symbol do
  describe "#method?" do
    it "returns true for method symbols" do
      sym = described_class.new(name: :foo, kind: :method, file_path: "a.rb", line: 1, column: 0)
      expect(sym.method?).to be true
      expect(sym.constant?).to be false
    end

    it "returns false for constant symbols" do
      sym = described_class.new(name: :FOO, kind: :constant, file_path: "a.rb", line: 1, column: 0)
      expect(sym.method?).to be false
      expect(sym.constant?).to be true
    end
  end
end

RSpec.describe Reweave::Semantic::SymbolTable do
  let(:table) { described_class.new }

  describe "#add_method / #resolve_method" do
    it "resolves instance methods by namespace" do
      table.add_method(:name, "User", "user.rb", 1, 0, "def name; end")
      sym = table.resolve_method(:name, "User")
      expect(sym).to_not be_nil
      expect(sym.name).to eq(:name)
      expect(sym.kind).to eq(:method)
      expect(sym.namespace).to eq("User")
      expect(sym.file_path).to eq("user.rb")
      expect(sym.line).to eq(1)
    end

    it "resolves class methods (def self.foo)" do
      table.add_method(:find_by_email, "User", "user.rb", 5, 0, "def self.find_by_email; end", instance_method: false)
      sym = table.resolve_method(:find_by_email, "User")
      expect(sym).to_not be_nil
      expect(sym.file_path).to eq("user.rb")
      expect(sym.line).to eq(5)
    end

    it "returns nil for unknown methods" do
      expect(table.resolve_method(:nonexistent, "User")).to be_nil
    end

    it "returns nil when namespace does not match" do
      table.add_method(:name, "User", "user.rb", 1, 0, "def name; end")
      expect(table.resolve_method(:name, "Admin")).to be_nil
    end
  end

  describe "#add_constant / #resolve_constant" do
    it "resolves top-level constants" do
      table.add_constant(:MAX_RETRIES, "constants.rb", 1, 0, "MAX_RETRIES = 3")
      sym = table.resolve_constant("MAX_RETRIES")
      expect(sym).to_not be_nil
      expect(sym.name).to eq(:MAX_RETRIES)
      expect(sym.kind).to eq(:constant)
    end

    it "resolves namespaced constants" do
      table.add_constant(:BaseController, "admin/base_controller.rb", 1, 0, "class BaseController; end", namespace: "Admin")
      sym = table.resolve_constant("Admin::BaseController")
      expect(sym).to_not be_nil
      expect(sym.namespace).to eq("Admin")
    end

    it "returns nil for unknown constants" do
      expect(table.resolve_constant("UNKNOWN")).to be_nil
    end
  end

  describe "#size and #empty?" do
    it "reports correct size" do
      expect(table).to be_empty
      expect(table.size).to eq(0)

      table.add_method(:foo, "Bar", "a.rb", 1, 0, "def foo; end")
      expect(table).to_not be_empty
      expect(table.size).to eq(1)

      table.add_constant(:BAZ, "a.rb", 2, 0, "BAZ = 1")
      expect(table.size).to eq(2)
    end
  end
end

RSpec.describe Reweave::Semantic::SymbolCollector do
  let(:table) { Reweave::Semantic::SymbolTable.new }
  let(:file_path) { "/tmp/test_user.rb" }
  let(:source) do
    <<~RUBY
      class User < ApplicationRecord
        def name
          @name
        end

        def self.find_by_email(email)
          where(email: email).first
        end
      end

      MAX_RETRIES = 3
    RUBY
  end

  it "collects instance methods, class methods, and constants from one file" do
    collector = described_class.new(table, file_path, source: source)
    collector.run(Prism.parse(source).value)

    expect(table.size).to eq(4)

    expect(table.resolve_method(:name, "User")).to_not be_nil
    expect(table.resolve_method(:find_by_email, "User")).to_not be_nil
    expect(table.resolve_constant("MAX_RETRIES")).to_not be_nil
    expect(table.resolve_constant("User")).to_not be_nil
  end

  it "records correct file paths and line numbers" do
    collector = described_class.new(table, file_path, source: source)
    collector.run(Prism.parse(source).value)

    sym = table.resolve_method(:name, "User")
    expect(sym.file_path).to eq(file_path)
    expect(sym.line).to eq(2)

    sym = table.resolve_method(:find_by_email, "User")
    expect(sym.file_path).to eq(file_path)
    expect(sym.line).to eq(6)

    sym = table.resolve_constant("MAX_RETRIES")
    expect(sym.file_path).to eq(file_path)
    expect(sym.line).to eq(11)
  end
end

RSpec.describe Reweave::Semantic::Analyzer do
  let(:tmpdir) { Dir.mktmpdir }
  let(:project) { Reweave::Execution::Project.from_path(tmpdir, patterns: ["**/*.rb"]) }

  after { FileUtils.rm_rf(tmpdir) }

  it "builds a cross-file symbol table from a project" do
    FileUtils.mkdir_p("#{tmpdir}/app/models")

    File.write("#{tmpdir}/app/models/user.rb", <<~RUBY)
      class User < ApplicationRecord
        def name
          @name
        end
      end
    RUBY

    File.write("#{tmpdir}/app/models/post.rb", <<~RUBY)
      class Post < ApplicationRecord
        def title
          @title
        end
      end
    RUBY

    analyzer = described_class.new(project)
    table = analyzer.analyze

    expect(table.size).to eq(4) # User class, User#name, Post class, Post#title
    expect(table.resolve_method(:name, "User")).to_not be_nil
    expect(table.resolve_method(:title, "Post")).to_not be_nil
    expect(table.resolve_constant("User")).to_not be_nil
    expect(table.resolve_constant("Post")).to_not be_nil
  end

  it "resolves symbols across files" do
    File.write("#{tmpdir}/user.rb", <<-'RUBY')
      class User
        def full_name
          "#{first_name} #{last_name}"
        end
      end
    RUBY

    File.write("#{tmpdir}/controller.rb", <<~RUBY)
      class UsersController
        def index
          User.all
        end
      end
    RUBY

    analyzer = described_class.new(project)
    table = analyzer.analyze

    # User#full_name defined in user.rb
    expect(table.resolve_method(:full_name, "User")).to_not be_nil
    # UsersController#index defined in controller.rb
    expect(table.resolve_method(:index, "UsersController")).to_not be_nil
    # User constant defined in user.rb
    expect(table.resolve_constant("User")).to_not be_nil
  end
end
