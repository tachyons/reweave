# frozen_string_literal: true

module Reweave
  module Editing
    Edit = Data.define(
      :source_id,
      :start_offset,
      :end_offset,
      :replacement,
      :recipe_name
    ) do
      def length
        end_offset - start_offset
      end

      def insertion?
        start_offset == end_offset
      end

      def deletion?
        replacement.empty?
      end

      def replacement?
        !insertion? && !deletion?
      end

      def overlaps?(other)
        return false unless source_id == other.source_id
        start_offset < other.end_offset && other.start_offset < end_offset
      end

      def adjacent?(other)
        return false unless source_id == other.source_id
        end_offset == other.start_offset || other.end_offset == start_offset
      end

      def contains_offset?(offset)
        offset.between?(start_offset, end_offset)
      end

      def to_s
        type = if insertion?
          "insert"
        else
          deletion? ? "delete" : "replace"
        end
        "#{type} @#{start_offset}-#{end_offset}: #{replacement.inspect}"
      end
    end
  end
end
