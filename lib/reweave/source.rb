# frozen_string_literal: true

require_relative "parser"
require_relative "editing"

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
      @visitor = nil
    end

    attr_accessor :visitor

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

    # Replace a node's source with new text
    def replace(node, new_source)
      loc = node.location
      @edits ||= Editing::EditSet.new
      @edits.add(Editing.replace(@identity, loc.start_offset, loc.end_offset, new_source, "AST::Node"))
      @visitor&.instance_variable_get(:@edits)&.add(Editing.replace(@identity, loc.start_offset, loc.end_offset, new_source, "AST::Node"))
    end

    # Replace a location with new text
    def replace_location(location, new_source)
      @edits ||= Editing::EditSet.new
      @edits.add(Editing.replace(@identity, location.start_offset, location.end_offset, new_source, "AST::Node"))
      @visitor&.instance_variable_get(:@edits)&.add(Editing.replace(@identity, location.start_offset, location.end_offset, new_source, "AST::Node"))
    end

    # Access accumulated edits (for use during traversal)
    def edits
      @edits ||= Editing::EditSet.new
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
