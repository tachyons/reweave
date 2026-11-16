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
        files = Reweave::Discovery::FileDiscoverer.discover(root, patterns: patterns, exclude: exclude)
        source_files = SourceSet.from_paths(files)
        new(root, source_files: source_files)
      end

      def add_source_file(path)
        file = SourceFile.new(path: File.join(@root, path))
        @source_files.add(file)
        file
      end

      def remove_source_file(path)
        @source_files.remove(File.join(@root, path))
      end

      def find_source_file(path)
        @source_files[File.join(@root, path)]
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
