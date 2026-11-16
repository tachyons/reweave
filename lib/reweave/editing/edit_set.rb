# frozen_string_literal: true

require_relative "edit"

module Reweave
  module Editing
    class EditSet
      include Enumerable

      def initialize(edits = [])
        @edits = edits
      end

      def add(edit)
        @edits << edit
        self
      end

      def <<(edit)
        add(edit)
      end

      def each(&block)
        @edits.each(&block)
      end

      def empty?
        @edits.empty?
      end

      def size
        @edits.size
      end

      def for_source(source_id)
        EditSet.new(@edits.select { |e| e.source_id == source_id })
      end

      def validate!
        validate_offsets!
        validate_overlaps!
        validate_encoding!
        self
      end

      def apply(source)
        Editor.apply(source, self)
      end

      def to_a
        @edits.dup
      end

      def +(other)
        EditSet.new(@edits + other.to_a)
      end

      private

      def validate_offsets!
        @edits.each do |edit|
          if edit.start_offset < 0 || edit.end_offset < 0
            raise EditError, "Negative offset in edit: #{edit}"
          end
          if edit.start_offset > edit.end_offset
            raise EditError, "Start offset after end offset: #{edit}"
          end
        end
      end

      def validate_overlaps!
        by_source = @edits.group_by(&:source_id)
        by_source.each do |source_id, edits|
          sorted = edits.sort_by { |e| [e.start_offset, e.end_offset] }
          sorted.each_cons(2) do |a, b|
            if a.overlaps?(b)
              if a.insertion? && b.insertion? && a.end_offset == b.start_offset
                # Adjacent insertions at same position - allowed with deterministic ordering
                next
              end
              raise EditError, "Overlapping edits on source #{source_id}: #{a} overlaps #{b}"
            end
            if a.end_offset == b.start_offset && a.replacement? && b.replacement?
              raise EditError, "Adjacent replacements on source #{source_id}: #{a} then #{b}"
            end
          end
        end
      end

      def validate_encoding!
        # UTF-8 boundary validation would go here
        # For now, we trust the byte offsets from Prism
      end
    end
  end
end
