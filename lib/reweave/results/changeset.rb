# frozen_string_literal: true

require "diffy"

module Reweave
  module Results
    class FileChange
      attr_reader :path, :original_source, :updated_source, :recipes, :change_type, :diff

      def initialize(path:, original_source:, updated_source:, recipes:, change_type: :modified)
        @path = path
        @original_source = original_source
        @updated_source = updated_source
        @recipes = recipes
        @change_type = change_type
        @diff = generate_diff
      end

      def changed?
        @original_source != @updated_source
      end

      def modified?
        @change_type == :modified
      end

      def created?
        @change_type == :created
      end

      def deleted?
        @change_type == :deleted
      end

      def renamed?
        @change_type == :renamed
      end

      private

      def generate_diff
        return "" unless changed?
        Diffy::Diff.new(@original_source, @updated_source, context: 3).to_s(:text)
      end
    end

    class ChangeSet
      include Enumerable

      def initialize(changes = [])
        @changes = changes
      end

      def add(change)
        @changes << change
      end

      def each(&block)
        @changes.each(&block)
      end

      def changed_files
        select(&:changed?)
      end

      def modified_files
        select(&:modified?)
      end

      def created_files
        select(&:created?)
      end

      def deleted_files
        select(&:deleted?)
      end

      def recipes
        @changes.flat_map(&:recipes).uniq
      end

      def empty?
        @changes.empty?
      end

      def size
        @changes.size
      end

      def to_a
        @changes.dup
      end
    end
  end
end
