# frozen_string_literal: true

require_relative "editing/edit"
require_relative "editing/edit_set"
require_relative "editing/editor"

module Reweave
  module Editing
    class EditError < StandardError; end

    def self.replace(source_id, start_offset, end_offset, replacement, recipe_name)
      Edit.new(source_id:, start_offset:, end_offset:, replacement:, recipe_name:)
    end

    def self.insert(source_id, offset, text, recipe_name)
      Edit.new(source_id:, start_offset: offset, end_offset: offset, replacement: text, recipe_name:)
    end

    def self.delete(source_id, start_offset, end_offset, recipe_name)
      Edit.new(source_id:, start_offset:, end_offset:, replacement: "", recipe_name:)
    end
  end
end
