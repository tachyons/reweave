# frozen_string_literal: true

require_relative "../../reweave/source"

module Reweave
  module Execution
    class Project
      attr_reader :root, :source_files, :config

      def initialize(root, source_files: nil, config: nil)
        @root = File.expand_path(root)
        @source_files = source_files || SourceSet.new
        @config = config || {}
      end

      def self.from_path(root, patterns: ["**/*.rb"], exclude: [])
        root = File.expand_path(root)
        files = Reweave::Discovery::FileDiscoverer.discover(root, patterns: patterns, exclude: exclude)
        # Store paths relative to project root so writes go to the right place
        rel_files = files.map { |f| f.delete_prefix(root + "/") }
        source_files = SourceSet.from_paths(rel_files, root: root)
        new(root, source_files: source_files)
      end

      def add_source_file(path)
        # path is relative to project root
        abs = File.join(@root, path)
        file = SourceFile.new(path: path)
        file.source = File.read(abs, encoding: "bom|utf-8")
        @source_files.add(file)
        file
      end

      def remove_source_file(path)
        @source_files.remove(path)
      end

      def find_source_file(path)
        @source_files[path]
      end

      def valid_source_files
        @source_files.valid_files
      end

      def paths
        @source_files.paths
      end
    end
  end
end
