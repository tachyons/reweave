# frozen_string_literal: true

module Reweave
  module Discovery
    class FileDiscoverer
      def self.discover(root, patterns: ["**/*.rb"], exclude: [])
        root = File.expand_path(root)
        all_files = []

        patterns.each do |pattern|
          Dir.glob(File.join(root, pattern), File::FNM_DOTMATCH).each do |path|
            next unless File.file?(path)
            next if exclude.any? { |ex| File.fnmatch(ex, path, File::FNM_PATHNAME) || File.fnmatch(ex, File.basename(path)) }
            next if path.include?("/.git/")
            all_files << path
          end
        end

        all_files.uniq.sort
      end
    end
  end
end
