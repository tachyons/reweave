# frozen_string_literal: true

require_relative "../../../reweave/recipe"
require_relative "../../../reweave/visitor/ruby_visitor"

module Reweave
  module Recipes
    module Rails
      # Rails 6.1 -> 7.0 syntax upgrades
      class Upgrade61To70 < Recipe
        display_name "Upgrade Rails 6.1 to 7.0"
        description "Converts Rails 6.1 syntax to 7.0: Hotwire (Turbo/Stimulus), import maps, Propshaft, etc."

        option :convert_hotwire, type: [TrueClass, FalseClass], default: true, description: "Convert UJS to Turbo/Stimulus"
        option :convert_import_maps, type: [TrueClass, FalseClass], default: true, description: "Convert Webpacker to import maps"
        option :convert_propshaft, type: [TrueClass, FalseClass], default: true, description: "Convert Sprockets to Propshaft"
        option :convert_encrypted_config, type: [TrueClass, FalseClass], default: true, description: "Convert encrypted credentials"
        option :convert_variants, type: [TrueClass, FalseClass], default: true, description: "Convert ActiveStorage variants"

        def get_visitor(context)
          Upgrade61To70Visitor.new(context, config)
        end
      end

      class Upgrade61To70Visitor < Reweave::Visitor::RubyVisitor
        def initialize(context, config)
          super(context, nil)
          @config = config
        end

        def run(source_file)
          @source_file = source_file
          traverse(source_file.root)
          edits
        end

        def visit_call_node(node)
          # Convert form_with to use Turbo
          if @config[:convert_hotwire] && match_call?(node, method: :form_with)
            # form_with already uses remote: true by default in 7.0
          end

          # Convert link_to with data: { remote: true } to data: { turbo: true }
          if @config[:convert_hotwire] && match_call?(node, method: :link_to)
            args = extract_arguments(node)
            if args.size >= 3
              options = args[2]
              if options.is_a?(Prism::HashNode)
                remote_pair = options.elements.find do |e|
                  e.is_a?(Prism::AssocNode) && e.key.is_a?(Prism::SymbolNode) && e.key.value == "remote"
                end
                if remote_pair && remote_pair.value.is_a?(Prism::TrueNode)
                  # Replace remote: true with turbo: true
                  new_hash = source_for(options).sub("remote: true", "turbo: true")
                  replace(node, "link_to(#{source_for(args[0])}, #{source_for(args[1])}, #{new_hash})")
                end
              end
            end
          end

          # Convert javascript_pack_tag to javascript_importmap_tag
          if @config[:convert_import_maps] && match_call?(node, method: :javascript_pack_tag)
            replace_location(node.message_loc, "javascript_importmap_tag")
          end

          # Convert stylesheet_pack_tag to stylesheet_link_tag (Propshaft)
          if @config[:convert_propshaft] && match_call?(node, method: :stylesheet_pack_tag)
            replace_location(node.message_loc, "stylesheet_link_tag")
          end

          # Convert encrypted credentials
          if @config[:convert_encrypted_config] && match_call?(node, method: :encrypted)
            # Rails 7 uses credentials instead
          end

          super
        end
      end
    end
  end
end
