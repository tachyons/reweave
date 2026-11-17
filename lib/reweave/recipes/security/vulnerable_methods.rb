# frozen_string_literal: true

require_relative "../../../reweave/recipe/declarative_recipe"

module Reweave
  module Recipes
    module Security
      # Replace vulnerable method calls with safe alternatives
      class VulnerableMethods < Reweave::Recipe::DeclarativeRecipe
        display_name "Vulnerable Method Replacement"
        description "Replace insecure method calls with safe alternatives"

        option :replace_yaml_load, type: [TrueClass, FalseClass], default: true, description: "Replace YAML.load with YAML.safe_load"
        option :replace_eval, type: [TrueClass, FalseClass], default: true, description: "Replace eval with safe alternatives"
        option :replace_marshal_load, type: [TrueClass, FalseClass], default: true, description: "Replace Marshal.load with safe alternatives"
        option :replace_system_backticks, type: [TrueClass, FalseClass], default: false, description: "Flag system/backticks with user input"

        # YAML.load -> YAML.safe_load
        transform_call(
          method: ->(instance) { ->(name) { instance.config[:replace_yaml_load] && name == :load } },
          receiver: ->(instance) { "YAML" }
        ) do |node, instance|
          node.replace("YAML.safe_load(#{node.args.map { |a| node.source_for(a) }.join(", ")})")
        end

        # eval -> safe alternative warning
        transform_call(
          method: ->(instance) { ->(name) { instance.config[:replace_eval] && name == :eval } }
        ) do |node, instance|
          args = node.args.map { |a| node.source_for(a) }.join(", ")
          node.replace("# SECURITY: eval is dangerous. Consider using a safe alternative.\neval(#{args})")
        end

        # Marshal.load -> safe alternative
        transform_call(
          method: ->(instance) { ->(name) { instance.config[:replace_marshal_load] && name == :load } },
          receiver: ->(instance) { "Marshal" }
        ) do |node, instance|
          node.replace("# SECURITY: Marshal.load is dangerous for untrusted data.\n# Consider using JSON.parse or a safe deserializer.\nMarshal.load(#{node.args.map { |a| node.source_for(a) }.join(", ")})")
        end

        # system/backticks with string interpolation -> warn
        transform_call(
          method: ->(instance) { ->(name) { instance.config[:replace_system_backticks] && %i[system `].include?(name) } }
        ) do |node, instance|
          args = node.args.map { |a| node.source_for(a) }.join(", ")
          if node.args.any? { |a| a.is_a?(Reweave::AST::Node) && a.prism_node.is_a?(Prism::InterpolatedStringNode) }
            node.replace("# SECURITY: Avoid user input in system/backticks.\n# Use safe alternatives like Open3.popen3 or Shellwords.escape\nsystem(#{args})")
          end
        end

        # Open3.popen3 is safer than system/backticks
        transform_call(
          method: ->(instance) { ->(name) { name == :popen3 } },
          receiver: ->(instance) { "Open3" }
        ) do |node, instance|
          # Already safe, but we can add a comment
          node.replace("# SAFE: Open3.popen3 is a secure alternative to system/backticks\nOpen3.popen3(#{node.args.map { |a| node.source_for(a) }.join(", ")})")
        end
      end
    end
  end
end
