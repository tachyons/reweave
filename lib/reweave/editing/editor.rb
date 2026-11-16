# frozen_string_literal: true

require_relative "edit_set"

module Reweave
  module Editing
    class Editor
      class << self
        def apply(source, edit_set)
          edit_set.validate!
          source = source.dup # Ensure mutable
          edits_by_source = edit_set.group_by(&:source_id)

          edits_by_source.each_value do |edits|
            sorted = edits.sort_by { |e| -e.start_offset }
            sorted.each do |edit|
              apply_edit(source, edit)
            end
          end
          source
        end

        def apply_edit(source, edit)
          if edit.start_offset > source.bytesize || edit.end_offset > source.bytesize
            raise EditError, "Edit offsets exceed source length: #{edit} (source: #{source.bytesize} bytes)"
          end

          # Validate UTF-8 boundaries
          unless valid_utf8_boundary?(source, edit.start_offset)
            raise EditError, "Edit start offset splits UTF-8 sequence: #{edit}"
          end
          unless valid_utf8_boundary?(source, edit.end_offset)
            raise EditError, "Edit end offset splits UTF-8 sequence: #{edit}"
          end

          source[edit.start_offset...edit.end_offset] = edit.replacement
        end

        def valid_utf8_boundary?(source, offset)
          return true if offset == 0 || offset == source.bytesize

          # Check if offset is in the middle of a UTF-8 sequence
          # UTF-8 continuation bytes start with 10xxxxxx
          byte = source.getbyte(offset)
          return true unless byte

          # If it's a continuation byte, we're in the middle of a sequence
          (byte & 0xC0) != 0x80
        end
      end
    end
  end
end
