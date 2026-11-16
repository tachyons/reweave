# frozen_string_literal: true

require_relative "parser"

module Reweave
  class SourceFile
    attr_reader :path, :source, :parse_result, :root, :diagnostics, :encoding, :identity

    def initialize(path:, source: nil)
      @path = path
      @source = source || File.read(path, encoding: "bom|utf-8")
      @encoding = @source.encoding
      @parse_result = Parser.parse(@source, path: @path)
      @root = @parse_result.root
      @diagnostics = @parse_result.diagnostics
      @identity = object_id
    end

    def valid?
      @parse_result.success?
    end

    def errors
      @parse_result.errors
    end

    def warnings
      @parse_result.warnings
    end

    def reparse!
      @parse_result = Parser.parse(@source, path: @path)
      @root = @parse_result.root
      @diagnostics = @parse_result.diagnostics
      self
    end

    def apply_edits(edits)
      @source = Editing::Editor.apply(@source, edits)
      reparse!
    end

    def ==(other)
      other.is_a?(SourceFile) && other.path == @path && other.identity == @identity
    end
    alias_method :eql?, :==
  end

  class SourceSet
    include Enumerable

    def initialize(files = [])
      @files = files
      @by_path = files.each_with_object({}) { |f, h| h[f.path] = f }
    end

    def self.from_paths(paths)
      new(paths.map { |p| SourceFile.new(path: p) })
    end

    def each(&block)
      @files.each(&block)
    end

    def [](path)
      @by_path[path]
    end

    def paths
      @files.map(&:path)
    end

    def valid_files
      select(&:valid?)
    end

    def invalid_files
      reject(&:valid?)
    end

    def add(file)
      @files << file
      @by_path[file.path] = file
    end

    def remove(path)
      file = @by_path.delete(path)
      @files.delete(file) if file
      file
    end
  end
end
